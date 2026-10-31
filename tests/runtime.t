use strict;
use warnings;
use FindBin;
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;
use Config qw(%Config);
use Time::HiRes qw(time);

use lib "$FindBin::Bin/..";

require Plugins::BlissGuidance::Runtime;

my $temporary = tempdir(CLEANUP => 1);
my $provider = File::Spec->catfile($temporary, 'provider.pl');
open my $fh, '>', $provider or die "cannot write $provider: $!";
print {$fh} <<'PROVIDER';
use strict;
use warnings;
use JSON::PP qw(decode_json encode_json);
$| = 1;
while (my $line = <STDIN>) {
    my $request = decode_json($line);
    if ($request->{type} eq 'describe') {
        print encode_json({ type => 'manifest', spi_version => 2, provider_id => 'fixture-provider', provider_version => 'test', protocol => 'bliss-guidance-jsonl-v2', capabilities => ['global_candidate_guidance'], channels => [] }) . "\n";
    } elsif ($request->{type} eq 'prepare') {
        print encode_json({ type => 'prepared', provider_id => 'fixture-provider', snapshot_id => 'fixture', diagnostics => { details => { accepted_anchors_v2 => $request->{anchors}, log_events_v1 => [
            { event_version => 'guidance_log_event_v1', level => 'info', phase => 'prepare', event => 'fixture_prepared', provider_id => 'fixture-provider' },
            { event_version => 'unknown', level => 'info', phase => 'prepare', event => 'ignored', provider_id => 'fixture-provider' }
        ] } } }) . "\n";
    } elsif ($request->{type} eq 'score') {
        print encode_json({ type => 'scores', provider_id => 'fixture-provider', request_id => $request->{request_id}, signals => [{ candidate_id => 'track-a', channel => 'playcount', scope => 'global', score => -0.5, confidence => 1, observation => { playcount => 3 } }], diagnostics => { details => { log_events_v1 => [
            { event_version => 'guidance_log_event_v1', level => 'debug', phase => 'score', event => 'fixture_scored', provider_id => 'fixture-provider', result_count => 1 }
        ] } } }) . "\n";
    } elsif ($request->{type} eq 'close') {
        print encode_json({ type => 'closed', provider_id => 'fixture-provider' }) . "\n";
    }
}
PROVIDER
close $fh;

my $result = Plugins::BlissGuidance::Runtime::score_batch({
    id => 'fixture-provider',
    program => $Config{perlpath},
    argv => [$provider],
    options => { as_of_unix_seconds => 100 },
    artifacts => [],
    resources => [],
}, {
    job_id => 'fixture-job',
    deadline_ms => 500,
    candidates => [{ candidate_id => 'track-a', lms_urlmd5 => 'abc' }],
});

ok($result->{valid}, 'bounded JSONL session succeeds');
is($result->{signals}->[0]->{candidate_id}, 'track-a', 'signal is returned for the supplied candidate');
is($result->{signals}->[0]->{observation}->{playcount}, 3, 'structured observation is preserved');
is_deeply(
    [map { $_->{event} } @{$result->{log_events}}],
    [qw(fixture_prepared fixture_scored)],
    'valid prepare and score log events are preserved in order',
);

# SPI v2 already defines prepare.anchors. The generic runtime must pass
# host-supplied anchors verbatim, regardless of provider identity.
my $seed = {
    anchor_id => 'seed-1',
    candidate_id => 'file:///music/seed.flac',
    lms_urlmd5 => '01020304',
    database_file => 'seed.flac',
};
my $anchored = Plugins::BlissGuidance::Runtime::score_batch({
    id => 'fixture-provider',
    program => $Config{perlpath},
    argv => [$provider],
    options => {},
    artifacts => [],
    resources => [],
}, {
    job_id => 'anchor-forwarding',
    deadline_ms => 500,
    anchors => [$seed],
    context => {
        scope => 'global',
        context_track_ids => ['seed-1'],
        left_anchor_id => undef,
        right_anchor_id => undef,
    },
    candidates => [{candidate_id => 'track-a', lms_urlmd5 => 'abc'}],
});
ok($anchored->{valid}, 'native SPI session accepts an existing global anchor');
is_deeply(
    $anchored->{prepared}{diagnostics}{details}{accepted_anchors_v2},
    [$seed],
    'prepare forwards exact anchor ID and candidate identity fields without translation',
);
is_deeply(
    $result->{prepared}{diagnostics}{details}{accepted_anchors_v2},
    [],
    'legacy anchor-free providers still receive an empty array',
);
my $malformed = Plugins::BlissGuidance::Runtime::score_batch({
    id => 'fixture-provider',
    program => $Config{perlpath},
    argv => [$provider],
}, {
    job_id => 'invalid-anchor-shape',
    deadline_ms => 500,
    anchors => { anchor_id => 'not-an-array' },
    candidates => [{candidate_id => 'track-a'}],
});
ok($malformed->{valid}, 'missing and invalid optional anchor collections remain backward compatible');
is_deeply(
    $malformed->{prepared}{diagnostics}{details}{accepted_anchors_v2},
    [],
    'an invalid anchors container never leaks untrusted object structure',
);

pipe(my $ready_read, my $ready_write)
    or die "cannot create stubborn provider fixture pipe: $!";
my $stubborn_pid = fork();
die "cannot fork stubborn provider fixture: $!" unless defined $stubborn_pid;
if (!$stubborn_pid) {
    close $ready_read;
    $SIG{TERM} = 'IGNORE';
    print {$ready_write} "ready\n";
    close $ready_write;
    select undef, undef, undef, 5;
    exit 0;
}
close $ready_write;
<$ready_read> eq "ready\n" or die 'stubborn provider fixture did not initialize';
close $ready_read;
my $started = time();
Plugins::BlissGuidance::Runtime::_reap($stubborn_pid);
my $elapsed_ms = int((time() - $started) * 1000);
cmp_ok($elapsed_ms, '<', 250,
    'an unresponsive provider cannot extend the host deadline while ignoring TERM');

done_testing();
