# Guidance-provider host settings UI

This repository owns the canonical schema-driven controls that a Lyrion host
vendors unchanged. A provider supplies descriptor metadata; a host supplies a
resolved `guidance_provider_sections` view model. Providers never inject HTML,
JavaScript, CSS, paths, or callbacks into the host page.

For each available provider, the partial renders in this order:

1. provider name;
2. provider-specific **Open <provider> settings** link;
3. **Use this provider** checkbox; and
4. the schema-declared controls, only while enabled.

Controls preserve the descriptor's `render_as` value. A `slider` renders the
Material Skin range plus numeric control; a `number` renders only a numeric
input. A host must not infer widget style from the value type.

Each control shows its effective-value source. The reset button appears only
for an explicit host override. Selecting **Use inherited default** changes the
current form value and annotation immediately, without submitting the page;
the ordinary settings Save action is the only persistence action. Explicit `0`
and `false` are valid host overrides, never a request to inherit.

The JavaScript only controls unsaved visibility/reset state. It does not fetch
provider data, start native processes, or submit a settings form.
