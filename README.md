# lms-bliss-guidance-host

Shared, source-only Perl support for Lyrion plugins that consume discoverable
Bliss guidance providers. It is bundled by host plugins; it is not an
installable Lyrion extension and has no settings page of its own.

It provides provider discovery, host/default/job policy resolution, and a
bounded JSONL v2 native-provider session. Hosts remain Bliss-first: providers
receive only candidates the host has already admitted and can only contribute
secondary reranking signals.

Better Call Bliss 0.21.0 and Bliss Mixer Lab already implement equivalent
host-pull discovery for the Library Signals provider. This repository is the
authoritative consolidation target for their shared discovery, policy, and
settings UI; it does not introduce a second provider protocol. See the
[`bliss-playlist-guidance-spi`](https://github.com/chrober/bliss-playlist-guidance-spi)
repository for the native protocol and provider contract.

Read [the architecture and runtime flows](GUIDANCE_PROVIDER_HOST_ARCHITECTURE.md)
for the static component boundaries and the dynamic discovery, settings, and
native-scoring flows. The canonical settings-page contract is documented in
[Guidance-provider host settings UI](GUIDANCE_PROVIDER_HOST_UI.md).
