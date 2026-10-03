use strict;
use warnings;
use FindBin;
use Test::More;

my $root = "$FindBin::Bin/..";
my $partial_path = "$root/HTML/settings/guidance-provider-controls.html";
my $script_path = "$root/HTML/settings/guidance-provider-controls.js";

open my $partial_fh, '<', $partial_path or die "cannot read $partial_path: $!";
my $partial = do { local $/; <$partial_fh> };
close $partial_fh;

like($partial, qr/guidance-provider-controls-\[\% provider\.provider_id/,
    'partial has a stable provider-controls wrapper');
like($partial, qr/guidance_ui\.settings_token/,
    'partial retains the installed-host label fallback');
like($partial, qr/provider\.available_label/,
    'partial renders the provider-carried availability label');
like($partial, qr/provider\.settings_link_label/,
    'partial renders the provider-carried settings link label');
like($partial, qr/provider\.enabled_label/,
    'partial renders the provider-carried enablement label');
like($partial, qr/control\.origin_prefix_label/,
    'partial renders the control-carried provenance prefix');
like($partial, qr/control\.reset_label/,
    'partial renders the control-carried inherited-default action label');
like($partial, qr/type="checkbox"/, 'partial renders enablement as a checkbox');
like($partial, qr/data-guidance-provider-controls=/,
    'checkbox is identifiable by the shared interaction script');
like($partial, qr/guidance-origin-\[\% control\.field_name/,
    'partial renders the effective-value origin marker');
like($partial, qr/type="button"/, 'reset action is a non-submitting button');
like($partial, qr/control\.origin == 'provider_default'/,
    'reset action is hidden for inherited provider settings');
like($partial, qr/render_as == 'slider'/, 'partial follows descriptor-declared slider rendering');
like($partial, qr/type="number"/, 'partial supports descriptor-declared number rendering');
like($partial, qr/data-guidance-provider-controls=/,
    'partial keeps the existing host checkbox-to-controls data contract');
like($partial, qr/data-guidance-inherited-field=/,
    'partial keeps the existing host inherited-default data contract');
like($partial, qr/data-guidance-dirty-marker=/,
    'partial keeps the existing host dirty-marker data contract');
like($partial, qr/guidance-origin-\[\% control\.field_name/,
    'partial keeps the existing host value-origin marker ID contract');
like($partial, qr/sliderInput_\[\% control\.minimum/,
    'slider controls retain Material Skin sliderInput metadata');

open my $script_fh, '<', $script_path or die "cannot read $script_path: $!";
my $script = do { local $/; <$script_fh> };
close $script_fh;

like($script, qr/data-guidance-provider-controls/, 'script binds the shared enablement checkbox');
like($script, qr/hidden/, 'script hides and reveals controls without a page reload');
like($script, qr/data-guidance-inherited-field/, 'script binds the inherited-default reset action');
unlike($script, qr/\.submit\s*\(/, 'script never submits settings implicitly');
like($script, qr/bindGuidanceInheritedMarkers/,
    'script marks explicit host overrides without submitting the form');
like($script, qr/root\.addEventListener\(\s*['"]input['"]\s*,\s*markMaterialSliderOverride\s*\)/,
    'script delegates Material Skin generated slider input when marking host overrides');
like($script, qr/root\.addEventListener\(\s*['"]change['"]\s*,\s*markMaterialSliderOverride\s*\)/,
    'script delegates Material Skin generated slider changes when marking host overrides');
like($script, qr/updateGuidanceProviderControls/,
    'script immediately hides or shows provider controls');

done_testing();
