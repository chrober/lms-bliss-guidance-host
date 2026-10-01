# lms-bliss-guidance-host

Shared, source-only Perl support for Lyrion plugins that consume discoverable
Bliss guidance providers. It is bundled by host plugins; it is not an
installable Lyrion extension and has no settings page of its own.

It provides provider discovery, host/default/job policy resolution, and a
bounded JSONL v2 native-provider session. Hosts remain Bliss-first: providers
receive only candidates the host has already admitted and can only contribute
secondary reranking signals.

The first consumers are Better Call Bliss and Bliss Mixer Lab. See the
[`bliss-playlist-guidance-spi`](https://github.com/chrober/bliss-playlist-guidance-spi)
repository for the native protocol and provider contract.
