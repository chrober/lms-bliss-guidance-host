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

my $provider_owned = {
    descriptor => {controls => [{key => 'source', type => 'enum',
        values => [qw(lastmix api_key)], factory_default => 'lastmix',
        host_overridable => 0}]},
    defaults => {source => 'api_key'},
};
my $inherited = Plugins::BlissGuidance::Policy::resolve($provider_owned,
    {enabled => 1, overrides => {source => 'lastmix'}},
    {overrides => {source => 'lastmix'}});
is($inherited->{effective}{source}, 'api_key',
    'stale host and job overrides cannot override a provider-owned source');
is($inherited->{origins}{source}, 'provider_default',
    'the source retains provider-default provenance');

my $temporarily_unavailable = {
    descriptor => { controls => [{ key => 'mode', type => 'enum', values => [qw(shared primary)],
        unavailable_value_fallbacks => { follow => 'shared' }, factory_default => 'shared', host_overridable => 1 }] },
    defaults => { mode => 'shared' },
};
my $saved_state = { enabled => 1, overrides => { mode => 'follow' } };
my $fallback = Plugins::BlissGuidance::Policy::resolve($temporarily_unavailable, $saved_state, {});
ok($fallback->{valid}, 'a temporarily unavailable saved enum choice has a valid fallback');
is($fallback->{effective}{mode}, 'shared', 'fallback supplies an allowed effective value');
is($saved_state->{overrides}{mode}, 'follow', 'resolving fallback never changes the saved override');
is($fallback->{origins}{mode}, 'host_override', 'fallback preserves override provenance');
is($fallback->{fallbacks}{mode}, 'follow', 'the unavailable choice is available to the UI for annotation');
push @{$temporarily_unavailable->{descriptor}{controls}[0]{values}}, 'follow';
delete $temporarily_unavailable->{descriptor}{controls}[0]{unavailable_value_fallbacks};
my $restored = Plugins::BlissGuidance::Policy::resolve($temporarily_unavailable, $saved_state, {});
is($restored->{effective}{mode}, 'follow', 'the saved choice is restored when it becomes available again');

done_testing();

