use strict;
use warnings;
use FindBin;
use Test::More;

use lib "$FindBin::Bin/..";

require Plugins::BlissGuidance::SettingsModel;

my $discovery = {
    providers => [
        {
            provider_id => 'z-last',
            available   => 1,
            descriptor  => {
                display_name => 'Z Last',
                settings_uri => 'plugins/ZLast/settings/zlast.html',
                controls => [
                    {
                        key => 'oldest_first_days', type => 'integer', render_as => 'number',
                        minimum => 1, maximum => 3650, step => 1, factory_default => 365,
                        host_overridable => 1, label => 'Age horizon', help => 'Cap age comparison.',
                    },
                ],
            },
            defaults => { oldest_first_days => 365, settings_revision => 7 },
        },
        {
            provider_id => 'library-signals',
            available   => 1,
            descriptor  => {
                display_name => 'Library Signals',
                settings_uri => 'plugins/LibrarySignals/settings/librarysignals.html',
                controls => [
                    {
                        key => 'playcount_influence', type => 'integer', render_as => 'slider',
                        minimum => -100, maximum => 100, step => 1, factory_default => 0,
                        host_overridable => 1, label => 'Play-count influence', help => 'Prefer less-played tracks.',
                    },
                    {
                        key => 'last_played_horizon_days', type => 'integer', render_as => 'number',
                        minimum => 30, maximum => 1825, step => 1, factory_default => 180,
                        host_overridable => 1, label => 'Last-played horizon', help => 'Saturate old play dates.',
                    },
                ],
            },
            defaults => {
                playcount_influence => -80,
                last_played_horizon_days => 180,
                settings_revision => 9,
            },
        },
    ],
};

my $host_state = {
    providers => {
        'library-signals' => {
            enabled => 1,
            overrides => {
                playcount_influence => 0,
            },
        },
    },
};

my $sections = Plugins::BlissGuidance::SettingsModel::provider_sections(
    $discovery,
    $host_state,
    {
        host_id => 'bettercallbliss',
        source_labels => {
            host_override => 'Better Call Bliss setting',
            provider_default => 'Provider setting',
            factory_default => 'Provider factory default',
        },
    },
);

is_deeply(
    [ map { $_->{provider_id} } @$sections ],
    [ 'library-signals', 'z-last' ],
    'sections are descriptor ordered by provider ID',
);

my $library = $sections->[0];
ok($library->{enabled}, 'provider enablement is retained');
is($library->{settings_uri}, 'plugins/LibrarySignals/settings/librarysignals.html', 'provider settings URI is retained');
is($library->{settings_link_label}, 'Open Library Signals settings', 'settings link uses provider display name');

my ($playcount) = grep { $_->{key} eq 'playcount_influence' } @{$library->{controls}};
is($playcount->{effective_value}, 0, 'explicit zero remains an effective override');
is($playcount->{origin}, 'host_override', 'explicit zero has host override provenance');
is($playcount->{origin_label}, 'Better Call Bliss setting', 'host-localized provenance label is used');
is($playcount->{render_as}, 'slider', 'descriptor slider rendering remains a slider');
ok($playcount->{show_reset}, 'overridden control offers inherited-default reset');
is($playcount->{form_id}, 'guidance_library-signals_playcount_influence', 'control has a stable form ID');

my ($horizon) = grep { $_->{key} eq 'last_played_horizon_days' } @{$library->{controls}};
is($horizon->{effective_value}, 180, 'provider default is the effective inherited value');
is($horizon->{origin}, 'provider_default', 'provider default provenance is retained');
is($horizon->{render_as}, 'number', 'descriptor number rendering stays a number input');
ok(!$horizon->{show_reset}, 'inherited control has no reset action');
is($horizon->{marker_id}, 'guidance_library-signals_last_played_horizon_days_origin', 'control has a stable origin marker ID');

my $legacy_sections = Plugins::BlissGuidance::SettingsModel::provider_sections(
    $discovery,
    $host_state,
    {
        source_labels => {
            host_override => 'Better Call Bliss setting',
            provider_default => 'Provider setting',
            factory_default => 'Provider factory default',
        },
        field_names => {
            enabled => sub { return 'pref_guidance_provider_' . $_[0] . '_enabled'; },
            control => sub { return 'pref_guidance_provider_' . $_[0] . '_' . $_[1]; },
            inherit => sub { return 'inherit_guidance_provider_' . $_[0] . '_' . $_[1]; },
            dirty => sub { return 'dirty_guidance_provider_' . $_[0] . '_' . $_[1]; },
        },
        origin_label_token => sub { return 'HOST_' . uc($_[0]); },
    },
);
my $legacy_control = $legacy_sections->[0]->{controls}->[0];
is($legacy_sections->[0]->{enable_field_name},
    'pref_guidance_provider_library-signals_enabled',
    'host field-name policy keeps the established enablement field');
is($legacy_control->{field_name},
    'pref_guidance_provider_library-signals_playcount_influence',
    'host field-name policy keeps the established control field');
is($legacy_control->{inherit_field_name},
    'inherit_guidance_provider_library-signals_playcount_influence',
    'host field-name policy keeps the established inherited marker');
is($legacy_control->{dirty_field_name},
    'dirty_guidance_provider_library-signals_playcount_influence',
    'host field-name policy keeps the established dirty marker');
is($legacy_control->{origin_label_token}, 'HOST_HOST_OVERRIDE',
    'host supplies its localized origin token without altering policy provenance');
is($legacy_control->{label_token}, undef,
    'descriptor label token is passed through without host-localized substitution');
is_deeply($legacy_control->{enum_values}, [],
    'non-enum controls expose a stable empty enum list to the canonical partial');

done_testing();
