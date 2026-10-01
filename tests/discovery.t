use strict;
use warnings;
use FindBin;
use Test::More;

BEGIN {
    package Slim::Utils::PluginManager;
    our @ENABLED;
    sub enabledPlugins { return @ENABLED; }
    $INC{'Slim/Utils/PluginManager.pm'} = __FILE__;

    package Plugins::GuidanceFixture::Plugin;
    sub guidance_provider_descriptor_v1 {
        return {
            protocol_version => 1,
            provider_id => 'library-signals',
            display_name => 'Library Signals',
            settings_uri => 'plugins/LibrarySignals/settings/librarysignals.html',
            capabilities => ['play_count'],
            scopes => ['global_candidate'],
            settings_schema_version => 1,
            controls => [{
                key => 'playcount_influence', type => 'integer',
                minimum => -100, maximum => 100, factory_default => 0,
                host_overridable => 1, guidance_channel => 'playcount',
                render_as => 'slider',
            }],
            native_spi => {
                provider_id => 'library-signals-guidance', spi_version => 2,
                protocol => 'bliss-guidance-jsonl-v2',
                channels => { play_count => 'playcount' },
                artifact_kinds => ['eligible-candidate-identities-v1'],
                resource_kinds => ['lms-persist-sqlite-v1'],
            },
        };
    }
    sub guidance_provider_defaults_v1 { return { playcount_influence => -80, settings_revision => 2 }; }
    sub guidance_provider_status_v1 { return { available => 1 }; }
    sub guidance_provider_native_spi_config_v1 {
        return { id => 'library-signals-guidance', program => '/trusted/provider', options => {}, artifacts => [], resources => [] };
    }
}

use lib "$FindBin::Bin/..";
require Plugins::BlissGuidance::Discovery;

@Slim::Utils::PluginManager::ENABLED = ('Plugins::GuidanceFixture::Plugin');
my $discovery = Plugins::BlissGuidance::Discovery::discover();
is(scalar @{$discovery->{providers}}, 1, 'one provider is discovered');
ok($discovery->{providers}->[0]->{available}, 'valid provider is available');
is($discovery->{providers}->[0]->{provider_id}, 'library-signals', 'provider identity is retained');

my $config = Plugins::BlissGuidance::Discovery::native_spi_config(
    $discovery->{providers}->[0],
    { playcount_influence => -80 },
    { candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => '/trusted/candidates.json', sha256 => ('a' x 64) }, as_of_unix_seconds => 123 },
);
is($config->{id}, 'library-signals-guidance', 'trusted provider factory supplies its native configuration');

done_testing();
