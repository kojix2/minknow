require "./spec_helper"

describe Minknow do
  it "maps generated manager positions into public positions" do
    proto_position = MinknowApi::Manager::FlowCellPosition.new
    proto_position.name = "X0"
    rpc_ports = MinknowApi::Manager::FlowCellPosition::RpcPorts.new
    rpc_ports.secure = 9601_u32
    proto_position.rpc_ports = rpc_ports

    position = Minknow::FlowCellPosition.from_proto(proto_position, "localhost")

    position.name.should eq("X0")
    position.host.should eq("localhost")
    position.secure_port.should eq(9601)
  end

  it "lists registered positions" do
    manager = Minknow::Manager.new
    manager.register_position(Minknow::FlowCellPosition.new("X1", "127.0.0.1", 9502))

    manager.flow_cell_positions.map(&.name).should eq(["X1"])
  end

  it "connects to a position using its secure port" do
    manager = Minknow::Manager.new(Minknow::ConnectionConfig.new(host: "localhost", port: 9501, tls: true))
    position = Minknow::FlowCellPosition.new("X2", "localhost", 9600)

    connection = manager.connect(position)

    connection.endpoint.should eq("localhost:9600")
    connection.data.name.should eq(:data)
  end

  it "builds a gRPC address from config" do
    config = Minknow::ConnectionConfig.new(host: "localhost", port: 9501, tls: true)

    config.address.should eq("https://localhost:9501")
  end

  it "fails when secure port is missing" do
    manager = Minknow::Manager.new
    position = Minknow::FlowCellPosition.new("X3", "localhost")

    expect_raises(Minknow::MissingSecurePortError) do
      manager.connect(position)
    end
  end
end
