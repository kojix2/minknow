# minknow.cr

[![test](https://github.com/kojix2/minknow/actions/workflows/test.yml/badge.svg)](https://github.com/kojix2/minknow/actions/workflows/test.yml)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Fminknow%2Flines)](https://tokei.kojix2.net/github/kojix2/minknow)

🧬🎛️ [MinKNOW API](https://github.com/nanoporetech/minknow_api) for [Crystal](https://crystal-lang.org/)

## Installation

Add the dependency to your shard.yml:

```yaml
dependencies:
  minknow:
    github: kojix2/minknow
```

Run `shards install`

## Quick Start

```crystal
require "minknow"
```

Recommended first smoke test for a local MinKNOW installation:

```sh
crystal run examples/manager_info.cr
```

If you specifically want to see connected sequencing positions:

```sh
crystal run examples/list_devices.cr
```

For local MinKNOW installations, `examples/manager_info.cr` is a better first check than `examples/list_devices.cr` because it succeeds even when no sequencing device is attached.

## Public API

The intended public surface for v0.0.0 is:

- `Minknow::ConnectionConfig` for connection settings and auth/TLS behavior
- `Minknow::Manager` for Manager-level RPCs such as host info and flow cell positions
- `Minknow::FlowCellPosition` for discovered sequencing positions
- `Minknow::Connection` for position-specific connections returned by `Manager#connect`

The generated types under `src/generated` are shipped as implementation detail and may change shape more often than the high-level wrapper.

## Connection Behavior

`Minknow::ConnectionConfig` resolves MinKNOW connectivity in this order:

- Uses TLS by default against the manager port.
- Loads the trusted CA from `MINKNOW_TRUSTED_CA` when set, otherwise tries MinKNOW's default install paths.
- Loads a client certificate from `MINKNOW_API_CLIENT_CERTIFICATE_CHAIN` and `MINKNOW_API_CLIENT_KEY` when both are set.
- Uses `MINKNOW_AUTH_TOKEN` as a `local-auth` token when provided.
- Otherwise, for localhost connections, fetches the local auth token path from MinKNOW and injects `local-auth` automatically.
- Adds `PROTOCOL_TOKEN` as `protocol-auth` metadata when present.

Notes:

- The default manager port is expected to be `9501`, which is the secure gRPC entrypoint on modern MinKNOW installations.
- Local token lookup only helps for local connections. Remote connections should use an explicit auth token or client certificates.
- Client certificate support is available through `ConnectionConfig`, but broad production validation across different MinKNOW deployments is still ongoing in this pre-stable release.

## Environment Variables

Common environment variables:

```text
MINKNOW_HOST=localhost
MINKNOW_PORT=9501
MINKNOW_TLS=true
MINKNOW_TRUSTED_CA=/var/lib/minknow/data/rpc-certs/minknow/ca.crt
MINKNOW_AUTH_TOKEN=<developer-or-local-token>
MINKNOW_API_CLIENT_CERTIFICATE_CHAIN=/path/to/client-chain.pem
MINKNOW_API_CLIENT_KEY=/path/to/client-key.pem
PROTOCOL_TOKEN=<protocol-token>
MINKNOW_API_USE_LOCAL_TOKEN=0|1
```

Typical meanings:

- `MINKNOW_HOST`: MinKNOW host, usually `localhost`
- `MINKNOW_PORT`: Manager port, usually `9501`
- `MINKNOW_TLS`: `true` for secure manager connections, `false` only for non-standard setups
- `MINKNOW_TRUSTED_CA`: path to the MinKNOW CA certificate used to verify the server certificate
- `MINKNOW_AUTH_TOKEN`: explicit token sent as `local-auth`
- `MINKNOW_API_CLIENT_CERTIFICATE_CHAIN`: PEM certificate chain for client-certificate auth
- `MINKNOW_API_CLIENT_KEY`: PEM private key matching the client certificate chain
- `PROTOCOL_TOKEN`: token sent as `protocol-auth` when running inside MinKNOW-managed protocol contexts
- `MINKNOW_API_USE_LOCAL_TOKEN`: overrides automatic local token lookup; set to `0`/`false` to disable or `1`/`true` to force it

## Examples

Example details and runnable commands are documented in [examples/README.md](examples/README.md).

Quick pointers:

- `examples/manager_info.cr` is the recommended first smoke test
- `examples/list_devices.cr` shows visible sequencing positions
- `examples/simulated_protocol_preset_workflow.cr` demonstrates simulated devices + protocol/preset workflow

## Limitations

v0.0.0 intentionally has a narrow scope.

- The high-level wrapper currently focuses on Manager connectivity and the basic position discovery flow.
- Many generated MinKNOW services are present, but not all of them have ergonomic wrapper methods yet.
- Client certificate configuration is supported, but cross-environment validation is still limited.
- The API should be considered pre-stable until a later 0.x release defines stronger compatibility expectations.

## Troubleshooting

TLS certificate verify failed:

Set `MINKNOW_TRUSTED_CA` to the MinKNOW CA file, or confirm that MinKNOW's default CA path exists on the machine.

Unauthenticated:

For local connections, confirm that local guest access is enabled and that `MINKNOW_API_USE_LOCAL_TOKEN` is not disabling token lookup. For remote connections, provide `MINKNOW_AUTH_TOKEN` or client certificates.

`positions=0` from `list_devices.cr`:

This usually means the connection to MinKNOW succeeded but no sequencing positions are currently available or attached.

Client certificate configuration errors:

`MINKNOW_API_CLIENT_CERTIFICATE_CHAIN` and `MINKNOW_API_CLIENT_KEY` must be set together and must both point to existing PEM files.

## Release Checklist

Release checklist is documented in [DEVELOPMENT.md](DEVELOPMENT.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Development

Development notes and generation workflow are documented in [DEVELOPMENT.md](DEVELOPMENT.md).
