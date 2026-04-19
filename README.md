# minknow

Minimal Crystal client scaffolding for MinKNOW and Read Until development.

Current focus:
- ManagerService.flow_cell_positions integration
- list-devices style smoke test for MinKNOW connectivity

## Installation

1. Add the dependency to your shard.yml:

   ```yaml
   dependencies:
     minknow:
       path: ../minknow.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "minknow"
```

The first practical smoke test is examples/list_devices.cr.

It calls ManagerService.flow_cell_positions and prints the discovered MinKNOW
positions with their secure ports.

Example:

```sh
MINKNOW_HOST=localhost MINKNOW_PORT=9501 crystal run examples/list_devices.cr
```

Expected output shape:

```text
positions=<N>
<position_name>    host=<host>    secure_port=<port_or_n/a>
```

## Bring-up Checklist

1. Install dependencies:

  ```sh
  shards install
  ```

2. Compile library and example:

  ```sh
  crystal build src/minknow.cr
  crystal build examples/list_devices.cr
  ```

3. Optional spec check:

  ```sh
  crystal spec spec/minknow_spec.cr
  ```

4. Run against MinKNOW host:

  ```sh
  MINKNOW_HOST=localhost MINKNOW_PORT=9501 MINKNOW_TLS=true crystal run examples/list_devices.cr
  ```

## Development

During local workspace development, minknow depends on the local grpc/proto
shards via path dependencies.

Generated files:
- MinKNOW protobuf/gRPC outputs are kept under src/generated.

Known limitation (current branch):
- google/protobuf/descriptor.proto generation still needs keyword escaping
  hardening in proto.cr.
- A temporary placeholder file may be used at
  src/generated/google/protobuf/descriptor.pb.cr
  to unblock compilation while finishing that generator work.

## Contributing

1. Fork it (<https://github.com/your-github-user/minknow/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [kojix2](https://github.com/your-github-user) - creator and maintainer
