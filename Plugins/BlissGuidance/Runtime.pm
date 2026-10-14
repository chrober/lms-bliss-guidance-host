package Plugins::BlissGuidance::Runtime;

use strict;
use warnings;
use IO::Select;
use IPC::Open3 qw(open3);
use JSON::PP qw(encode_json decode_json);
use POSIX qw(WNOHANG);
use Symbol qw(gensym);
use Time::HiRes qw(time);

use constant SPI_VERSION => 2;
use constant PROTOCOL => 'bliss-guidance-jsonl-v2';
use constant MAX_LOG_EVENTS => 64;
use constant MAX_LOG_EVENT_BYTES => 16 * 1024;

sub score_batch {
    my ($config, $request) = @_;
    $config = {} unless ref($config) eq 'HASH';
    $request = {} unless ref($request) eq 'HASH';
    my $started = time();
    my $deadline_ms = int($request->{deadline_ms} || $config->{timeout_ms} || 500);
    $deadline_ms = 1 if $deadline_ms < 1;
    my $deadline = $started + ($deadline_ms / 1000);
    my $program = $config->{program} || '';
    return _failure('provider program is missing', $started)
        unless length $program && -x $program;
    my $provider_id = $config->{id} || '';
    return _failure('provider ID is missing', $started) unless length $provider_id;
    my @command = ($program, @{ref($config->{argv}) eq 'ARRAY' ? $config->{argv} : []});
    my ($in, $out, $err) = (undef, undef, gensym);
    my $pid = eval { open3($in, $out, $err, @command) };
    return _failure('provider could not be started: ' . ($@ || $!), $started)
        unless $pid;
    select((select($in), $| = 1)[0]);

    my $result = eval {
        my $manifest = _exchange($in, $out, $deadline, {
            type => 'describe', spi_version => SPI_VERSION,
        });
        _expect($manifest, 'manifest', $provider_id);
        die 'provider protocol is unsupported'
            unless ($manifest->{spi_version} || 0) == SPI_VERSION
                && ($manifest->{protocol} || '') eq PROTOCOL;

        my $prepared = _exchange($in, $out, $deadline, {
            type => 'prepare', spi_version => SPI_VERSION,
            job_id => $request->{job_id} || 'guidance-host',
            options => ref($config->{options}) eq 'HASH' ? $config->{options} : {},
            artifacts => ref($config->{artifacts}) eq 'ARRAY' ? $config->{artifacts} : [],
            resources => ref($config->{resources}) eq 'ARRAY' ? $config->{resources} : [],
            anchors => [],
        });
        _expect($prepared, 'prepared', $provider_id);

        my $scores = _exchange($in, $out, $deadline, {
            type => 'score', spi_version => SPI_VERSION,
            request_id => $request->{request_id} || 'score-1',
            context => ref($request->{context}) eq 'HASH' ? $request->{context} : {
                scope => 'global', left_anchor_id => undef,
                right_anchor_id => undef, context_track_ids => [],
            },
            candidates => ref($request->{candidates}) eq 'ARRAY' ? $request->{candidates} : [],
        });
        _expect($scores, 'scores', $provider_id);
        my $closed = _exchange($in, $out, $deadline, {
            type => 'close', spi_version => SPI_VERSION,
        });
        _expect($closed, 'closed', $provider_id);
        my @log_events = (
            @{_extract_log_events($prepared->{diagnostics})},
            @{_extract_log_events($scores->{diagnostics})},
        );
        splice @log_events, MAX_LOG_EVENTS if @log_events > MAX_LOG_EVENTS;
        {
            valid => 1,
            signals => ref($scores->{signals}) eq 'ARRAY' ? $scores->{signals} : [],
            manifest => $manifest,
            prepared => $prepared,
            diagnostics => $scores->{diagnostics} || {},
            log_events => \@log_events,
            elapsed_ms => int((time() - $started) * 1000),
            diagnostic => '',
        };
    };
    my $error = $@;
    close $in if $in;
    close $out if $out;
    close $err if $err;
    _reap($pid);
    return $result if $result;
    $error =~ s/\s+$// if defined $error;
    return _failure($error || 'provider session failed', $started);
}

sub _extract_log_events {
    my $diagnostics = shift;
    return [] unless ref($diagnostics) eq 'HASH'
        && ref($diagnostics->{details}) eq 'HASH'
        && ref($diagnostics->{details}->{log_events_v1}) eq 'ARRAY';
    my @events;
    for my $event (@{$diagnostics->{details}->{log_events_v1}}) {
        next unless _valid_log_event($event);
        push @events, { %$event };
        last if @events >= MAX_LOG_EVENTS;
    }
    return \@events;
}

sub _valid_log_event {
    my $event = shift;
    return 0 unless ref($event) eq 'HASH';
    return 0 unless ($event->{event_version} || '') eq 'guidance_log_event_v1';
    return 0 unless ($event->{level} || '') =~ /^(?:error|warning|info|debug)$/;
    return 0 unless defined $event->{phase} && length $event->{phase} && !ref($event->{phase});
    return 0 unless defined $event->{event} && length $event->{event} && !ref($event->{event});
    return 0 unless defined $event->{provider_id} && length $event->{provider_id}
        && !ref($event->{provider_id});
    my $encoded = eval { encode_json($event) };
    return 0 unless defined $encoded && length($encoded) <= MAX_LOG_EVENT_BYTES;
    return 1;
}

sub _exchange {
    my ($in, $out, $deadline, $request) = @_;
    print {$in} encode_json($request) . "\n" or die 'provider input write failed';
    my $remaining = $deadline - time();
    die 'provider session exceeded its deadline' if $remaining <= 0;
    my $select = IO::Select->new($out);
    my @ready = $select->can_read($remaining);
    die 'provider session exceeded its deadline' unless @ready;
    my $line = <$out>;
    die 'provider ended without a response' unless defined $line;
    my $response = eval { decode_json($line) };
    die 'provider returned invalid JSON' unless ref($response) eq 'HASH';
    if (($response->{type} || '') eq 'error') {
        die 'provider error ' . ($response->{code} || 'UNKNOWN') . ': '
            . ($response->{message} || 'unknown error');
    }
    return $response;
}

sub _expect {
    my ($response, $type, $provider_id) = @_;
    die "provider returned '$response->{type}' while '$type' was expected"
        unless ($response->{type} || '') eq $type;
    return if $type eq 'manifest';
    die 'provider response ID does not match configuration'
        unless ($response->{provider_id} || '') eq $provider_id;
}

sub _reap {
    my $pid = shift;
    return unless $pid;
    return if waitpid($pid, WNOHANG) == $pid;
    kill 'TERM', $pid;
    return if waitpid($pid, WNOHANG) == $pid;
    # The host deadline covers the complete native session.  A provider that
    # ignores TERM must not turn a 500 ms request into an unbounded wait.
    kill 'KILL', $pid;
    waitpid($pid, 0);
}

sub _failure {
    my ($diagnostic, $started) = @_;
    return {
        valid => 0,
        signals => [],
        elapsed_ms => int((time() - $started) * 1000),
        diagnostic => $diagnostic || 'provider session failed',
    };
}

1;
