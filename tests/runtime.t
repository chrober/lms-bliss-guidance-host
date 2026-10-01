use strict;
use warnings;
use FindBin;
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;
use Config qw(%Config);

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
        print encode_json({ type => 'prepared', provider_id => 'fixture-provider', snapshot_id => 'fixture', diagnostics => {} }) . "\n";
    } elsif ($request->{type} eq 'score') {
        print encode_json({ type => 'scores', provider_id => 'fixture-provider', request_id => $request->{request_id}, signals => [{ candidate_id => 'track-a', channel => 'playcount', scope => 'global', score => -0.5, confidence => 1, observation => { playcount => 3 } }], diagnostics => {} }) . "\n";
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

done_testing();
