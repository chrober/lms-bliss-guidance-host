# Guidance-provider host architecture

`lms-bliss-guidance-host` is shared source code vendored by Lyrion host
plugins. It is deliberately not a plugin, does not own a settings page, and
does not choose music. Its role is to discover trusted provider plugins,
resolve their effective policy, render the canonical host controls, and run a
bounded native-provider session when a host requests one.

Guidance remains secondary. A host first narrows candidates with its normal
Bliss algorithm and constraints; a provider can then attach bounded signals to
those already-admitted candidates.

## Static architecture

```mermaid
flowchart LR
    User["Lyrion user"]
    Host["Host plugin\nBetter Call Bliss or Bliss Mixer Lab"]
    Shared["lms-bliss-guidance-host\nDiscovery, Policy, SettingsModel, Runtime"]
    Provider["Installed guidance provider\nDescriptor, defaults, status, settings page"]
    Native["Optional native provider executable"]
    Spi["bliss-guidance-jsonl-v2"]
    Engine["Host music engine\nOptimizer or mixer"]

    User --> Host
    Host --> Shared
    Shared --> Provider
    Host --> Engine
    Shared --> Spi
    Engine --> Spi
    Spi --> Native
    Provider --> Native
```

The provider owns its default settings and backend configuration. The host
owns the opt-in switch and sparse per-host overrides. The shared library keeps
that boundary identical across host plugins.

## Discovery and settings flow

```mermaid
sequenceDiagram
    participant U as User
    participant H as Host settings page
    participant D as Shared discovery
    participant P as Provider plugin
    participant M as Shared settings model

    U->>H: Open settings
    H->>D: Discover enabled Lyrion modules
    D->>P: Read descriptor, defaults, and status
    P-->>D: Validated provider metadata
    D-->>H: Available providers
    H->>M: Resolve provider defaults and host overrides
    M-->>H: Schema-driven control sections
    H-->>U: Render opt-in checkbox and effective-value labels

    U->>H: Use inherited default
    H-->>U: Update form value and source label only
    U->>H: Save settings
    H->>M: Persist explicit host overrides
```

The browser-side controls only handle unsaved form state. Provider discovery,
policy resolution, and persistence stay in trusted Perl code.

## Runtime scoring flow

```mermaid
sequenceDiagram
    participant U as User or job
    participant H as Host plugin
    participant S as Shared policy and discovery
    participant E as Host music engine
    participant P as Native guidance provider

    U->>H: Start mix or preview
    H->>S: Resolve enabled providers and effective values
    S-->>H: Frozen policy and trusted native configuration
    H->>E: Submit Bliss-qualified candidate request
    E->>E: Apply Bliss distance, quality, and repeat constraints
    E->>P: Prepare with policy and trusted resources
    P-->>E: Prepared acknowledgement
    E->>P: Score admitted candidate batch
    P-->>E: Bounded guidance signals and diagnostics
    E-->>H: Selected tracks and selection trace
    H-->>U: Preview, queue action, or localized log output
```

Provider failures are non-fatal: the host retains its Bliss-only result when a
provider is unavailable, invalid, slow, or returns unusable output.
