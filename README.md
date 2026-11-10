# minknow.cr

[![Test](https://github.com/kojix2/minknow/actions/workflows/test.yml/badge.svg)](https://github.com/kojix2/minknow/actions/workflows/test.yml)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Fminknow%2Flines)](https://tokei.kojix2.net/github/kojix2/minknow)

Crystal bindings for the [MinKNOW API](https://github.com/nanoporetech/minknow_api).
Includes generated RPC types and wrappers for Manager, instance, device,
acquisition, protocol and live-read data services.

## Installation

Requires Crystal >= 1.20 and [libnghttp2](https://github.com/kojix2/grpc#installation).
Add this dependency, then run `shards install`:

```yaml
dependencies:
  minknow:
    github: kojix2/minknow
```

## Connect

```crystal
require "minknow"

manager = Minknow::Manager.new(
  Minknow::ConnectionConfig.new(host: "localhost", port: 9501, tls: true))
begin
  manager.fetch_flow_cell_positions.each do |position|
    puts "#{position.name}: #{position.host}:#{position.secure_port}"
  end
ensure
  manager.channel.close
end
```

Use `manager.connect(position)` for a position-specific connection. Its
`device`, `data`, `protocol`, `acquisition` and `instance` methods expose service
wrappers. For a first connection check without an attached sequencer, run:

```sh
crystal run examples/manager_info.cr
```

Pass `endpoint_config:` to `ConnectionConfig` to configure the gRPC channel.
For a short control call, create a fresh context with a deadline; a live-read
stream can instead use a separate context without a short fixed deadline:

```crystal
config = Minknow::ConnectionConfig.new(
  endpoint_config: GRPC::EndpointConfig.new(connect_timeout: 5.seconds))
control_context = config.client_context(deadline: 5.seconds)
manager = Minknow::Manager.new(config)
positions = manager.fetch_flow_cell_positions(control_context)
# A position-specific connection also accepts explicit contexts, e.g.
# connection.device(control_context) or connection.data(config.client_context).
manager.channel.close
```

## Authentication

Connections use TLS by default. Configure host/port/TLS through `ConnectionConfig`;
example scripts also accept `MINKNOW_HOST`, `MINKNOW_PORT` and `MINKNOW_TLS`.

| Environment variable | Purpose |
| --- | --- |
| `MINKNOW_TRUSTED_CA` | CA file; otherwise MinKNOW's installation paths are checked |
| `MINKNOW_AUTH_TOKEN` | Explicit `local-auth` token |
| `MINKNOW_API_CLIENT_CERTIFICATE_CHAIN` / `MINKNOW_API_CLIENT_KEY` | Client certificate and key; set both |
| `MINKNOW_API_USE_LOCAL_TOKEN` | Enable/disable automatic localhost token lookup |
| `PROTOCOL_TOKEN` | `protocol-auth` metadata |

Remote connections need explicit authentication. `auto_local_auth:` overrides
the lookup environment setting; `local_auth_lookup_port:` selects its Manager port.

## Development

Generated sources are included; ordinary use does not need `protoc`.
Run `crystal spec`. See [examples](examples/README.md) for runnable commands and
[DEVELOPMENT.md](DEVELOPMENT.md) for API regeneration and release checks.

`crystal spec spec/live_reads_large.cr` is an additional local-server test for
a 9 MiB signal field, setup and action responses. The committed `shard.lock`
and generated stubs include the required proto.cr and grpc.cr APIs; install
the matching dependencies with `shards install --frozen`.

License: [MIT](LICENSE).
