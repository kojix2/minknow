# Protobuf schemas

`google/protobuf/{any,descriptor,duration,empty,timestamp,wrappers}.proto` are
unmodified Protocol Buffers v3.21.12 schemas from
https://github.com/protocolbuffers/protobuf/tree/v3.21.12/src/google/protobuf.

Their copyright and BSD license notices are preserved in each schema. Keep
these notices when redistributing the schemas or generated code. The vendored
inputs make regeneration independent of the host's installed protobuf headers.

Update these inputs deliberately together with the generated Google types and
run `make gen` and `crystal spec` before committing.
