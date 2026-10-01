use strict;
use warnings;
use FindBin;
use Test::More;

use lib "$FindBin::Bin/..";

require Plugins::BlissGuidance::Policy;

my $provider = {
    provider_id => 'library-signals',
    descriptor => {
        settings_schema_version => 1,
        controls => [
            { key => 'playcount_influence', type => 'integer', minimum => -100, maximum => 100, factory_default => 0 },
            { key => 'last_played_horizon_days', type => 'integer', minimum => 30, maximum => 1825, factory_default => 180 },
        ],
    },
    defaults => { playcount_influence => -80, last_played_horizon_days => 365, settings_revision => 2 },
};

my $resolved = Plugins::BlissGuidance::Policy::resolve(
    $provider,
    { enabled => 1, overrides => { playcount_influence => -60 } },
    { overrides => { last_played_horizon_days => 90 } },
);

ok($resolved->{valid}, 'provider policy is valid');
ok($resolved->{enabled}, 'job/host policy enables the provider');
is($resolved->{effective}->{playcount_influence}, -60, 'host override replaces provider default');
is($resolved->{origins}->{playcount_influence}, 'host_override', 'host override provenance is retained');
is($resolved->{effective}->{last_played_horizon_days}, 90, 'job override wins over host and provider values');
is($resolved->{origins}->{last_played_horizon_days}, 'job_override', 'job override provenance is retained');

my $invalid = Plugins::BlissGuidance::Policy::resolve(
    $provider,
    { enabled => 1, overrides => { playcount_influence => 101 } },
    {},
);
ok(!$invalid->{valid}, 'out-of-range override is rejected');
like($invalid->{diagnostic}, qr/playcount_influence/, 'invalid control is identified');

done_testing();

