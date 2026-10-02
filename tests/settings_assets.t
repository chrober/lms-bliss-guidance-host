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

like($partial, qr/guidance-provider-section/, 'partial has a stable provider-section wrapper');
like($partial, qr/settings_link_label/, 'partial renders the provider-specific settings link label');
like($partial, qr/type="checkbox"/, 'partial renders enablement as a checkbox');
like($partial, qr/data-guidance-enable/, 'checkbox is identifiable by the shared interaction script');
like($partial, qr/marker_id/, 'partial renders the effective-value origin marker');
like($partial, qr/type="button"/, 'reset action is a non-submitting button');
like($partial, qr/show_reset/, 'reset action is conditional on an explicit host override');
like($partial, qr/render_as == 'slider'/, 'partial follows descriptor-declared slider rendering');
like($partial, qr/render_as == 'number'/, 'partial follows descriptor-declared number rendering');

open my $script_fh, '<', $script_path or die "cannot read $script_path: $!";
my $script = do { local $/; <$script_fh> };
close $script_fh;

like($script, qr/data-guidance-enable/, 'script binds the shared enablement checkbox');
like($script, qr/hidden/, 'script hides and reveals controls without a page reload');
like($script, qr/data-guidance-reset/, 'script binds the inherited-default reset action');
unlike($script, qr/\.submit\s*\(/, 'script never submits settings implicitly');

done_testing();
