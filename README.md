# lms-bliss-guidance-host

Shared, source-only Perl support for Lyrion plugins that consume discoverable
Bliss guidance providers. It is bundled by host plugins; it is not an
installable Lyrion extension and has no settings page of its own.

It provides provider discovery, host/default/job policy resolution, and a
bounded JSONL v2 native-provider session. Hosts remain Bliss-first: providers
receive only candidates the host has already admitted and can only contribute
secondary reranking signals.

## Architecture

```mermaid
flowchart LR
    User["Lyrion user"]
    Host["Host plugin"]
    Shared["Guidance host library\nDiscovery, Policy, SettingsModel, Runtime"]
    Provider["Installed guidance provider\nDescriptor, defaults, status, settings page"]
    Native["Optional native provider executable"]
    Spi["bliss-guidance-jsonl-v2"]
    Engine["Host music engine"]

    User --> Host
    Host --> Shared
    Shared --> Provider
    Host --> Engine
    Shared --> Spi
    Engine --> Spi
    Spi --> Native
    Provider --> Native
```

The provider owns default settings and backend configuration. The host owns
the opt-in switch and sparse per-host overrides. The shared library keeps that
boundary consistent across hosts.

## Discovery, settings, and runtime flow

```mermaid
sequenceDiagram
    participant U as User or job
    participant H as Host plugin
    participant S as Shared host library
    participant P as Provider plugin
    participant E as Host music engine
    participant N as Native provider

    U->>H: Open settings or start a job
    H->>S: Discover enabled providers
    S->>P: Read descriptor, defaults, and status
    P-->>S: Validated provider metadata
    S-->>H: Available providers and effective policy
    H-->>U: Render opt-in controls and source labels

    U->>H: Save explicit host overrides
    H->>E: Submit Bliss-qualified candidate request
    E->>E: Apply Bliss selection and host constraints
    E->>N: Prepare and score admitted candidates
    N-->>E: Bounded signals and diagnostics
    E-->>H: Selected tracks and selection trace
    H-->>U: Preview, queue action, or localized logs
```

Selecting **Use inherited default** updates only the current form value and
source label; the ordinary Save action is the only persistence action.
Provider failures are non-fatal: a host retains its Bliss-only result when a
provider is unavailable, invalid, slow, or returns unusable output.

## Settings UI contract

This repository owns the canonical schema-driven controls that a Lyrion host
vendors unchanged. A provider supplies descriptor metadata; a host supplies a
resolved `guidance_provider_sections` view model. Providers never inject HTML,
JavaScript, CSS, paths, or callbacks into a host page.

For each available provider, the partial renders, in order:

1. provider name;
2. provider-specific **Open <provider> settings** link;
3. **Use this provider** checkbox; and
4. schema-declared controls, only while enabled.

Controls preserve the descriptor's `render_as` value. A `slider` renders the
Material Skin range plus numeric control; a `number` renders only a numeric
input. A host must not infer widget style from the value type.

Each control shows its effective-value source. The reset button appears only
for an explicit host override. Selecting **Use inherited default** changes the
current form value and annotation immediately, without submitting the page;
the ordinary settings Save action is the only persistence action. Explicit `0`
and `false` are valid host overrides, never a request to inherit.

The JavaScript only controls unsaved visibility and reset state. It does not
fetch provider data, start native processes, or submit a settings form.

This repository is the authoritative consolidation target for shared
discovery, policy, and settings UI; it does not introduce a second provider
protocol. [Better Call Bliss](https://github.com/chrober/lms-better-call-bliss)
and [Bliss Mixer Lab](https://github.com/chrober/lms-blissmixer-lab) are current
examples of host plugins using this approach. See the
[`bliss-playlist-guidance-spi`](https://github.com/chrober/bliss-playlist-guidance-spi)
repository for the native protocol and provider contract.
