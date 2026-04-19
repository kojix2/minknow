# Examples

This directory contains runnable examples for the `minknow` shard.

## Prerequisites

Most examples assume a local MinKNOW instance.

Common environment variables:

```text
MINKNOW_HOST=localhost
MINKNOW_PORT=9501
MINKNOW_TLS=true
MINKNOW_TRUSTED_CA=/var/lib/minknow/data/rpc-certs/minknow/ca.crt
MINKNOW_AUTH_TOKEN=<developer-or-local-token>
```

## manager_info.cr

Recommended first smoke test. This queries manager-level host information and works even when no sequencing position is attached.

```sh
MINKNOW_HOST=localhost MINKNOW_PORT=9501 crystal run examples/manager_info.cr
```

## list_devices.cr

Lists currently visible sequencing positions.

```sh
MINKNOW_HOST=localhost MINKNOW_PORT=9501 crystal run examples/list_devices.cr
```

Expected output shape:

```text
positions=<N>
<position_name>    host=<host>    secure_port=<port_or_n/a>
```

## simulated_protocol_preset_workflow.cr

Runs a combined workflow for simulated devices, protocol discovery, and presets lookup.

```sh
crystal run examples/simulated_protocol_preset_workflow.cr -- \
  --host localhost \
  --port 9501 \
  --create-simulated true \
  --preset-id standard_sequencing \
  --protocol-limit 5
```

Optional filters for manager `find_protocols`:

```sh
crystal run examples/simulated_protocol_preset_workflow.cr -- \
  --flow-cell-code FLO-MIN106 \
  --sequencing-kit SQK-LSK114
```

Environment variables are still supported as fallback for backward compatibility.

## Client Certificate Snippet

If your MinKNOW setup requires client certificates, this minimal snippet shows configuration:

```crystal
require "minknow"

config = Minknow::ConnectionConfig.new(
  host: "localhost",
  port: 9501,
  tls: true,
  client_certificate_chain_path: "/path/to/client-chain.pem",
  client_private_key_path: "/path/to/client-key.pem",
)

manager = Minknow::Manager.new(config)
puts manager.get_version_info.minknow.try(&.full) || "n/a"
```
