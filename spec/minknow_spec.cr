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
    connection.data.should be_a(Minknow::DataService)
    connection.acquisition.should be_a(Minknow::AcquisitionService)
  end

  it "builds a gRPC address from config" do
    config = Minknow::ConnectionConfig.new(host: "localhost", port: 9501, tls: true)

    config.address.should eq("https://localhost:9501")
  end

  it "honors an explicit local authentication opt-out over the environment" do
    previous = ENV["MINKNOW_API_USE_LOCAL_TOKEN"]?
    begin
      ENV["MINKNOW_API_USE_LOCAL_TOKEN"] = "1"
      config = Minknow::ConnectionConfig.new(
        host: "localhost", auto_local_auth: false,
        authentication_token: nil, protocol_token: nil
      )

      config.local_auth_enabled?.should be_false
      config.effective_metadata.should be_empty
    ensure
      ENV["MINKNOW_API_USE_LOCAL_TOKEN"] = previous
    end
  end

  it "honors an explicit local authentication opt-in over the environment" do
    previous = ENV["MINKNOW_API_USE_LOCAL_TOKEN"]?
    begin
      ENV["MINKNOW_API_USE_LOCAL_TOKEN"] = "0"
      config = Minknow::ConnectionConfig.new(host: "localhost", auto_local_auth: true)

      config.local_auth_enabled?.should be_true
    ensure
      ENV["MINKNOW_API_USE_LOCAL_TOKEN"] = previous
    end
  end

  it "uses the environment when local authentication is unspecified" do
    previous = ENV["MINKNOW_API_USE_LOCAL_TOKEN"]?
    begin
      config = Minknow::ConnectionConfig.new(host: "localhost")
      ENV["MINKNOW_API_USE_LOCAL_TOKEN"] = "0"
      config.local_auth_enabled?.should be_false
      ENV["MINKNOW_API_USE_LOCAL_TOKEN"] = "1"
      config.local_auth_enabled?.should be_true
    ensure
      ENV["MINKNOW_API_USE_LOCAL_TOKEN"] = previous
    end
  end

  it "round-trips a default live reads setup request" do
    request = Minknow::DataService.setup_request
    decoded = Minknow::DataService::LiveRequest.decode(request.encode)
    setup = decoded.setup.not_nil!

    setup.first_channel.should eq(1_u32)
    setup.last_channel.should eq(512_u32)
    setup.raw_data_type.value.should eq(Minknow::DataService::RawDataType::CALIBRATED.value)
    setup.sample_minimum_chunk_size.should eq(0_u64)
    setup.accepted_first_chunk_classifications.should be_empty
    decoded.actions.should be_nil
  end

  it "round-trips a customized live reads setup request" do
    request = Minknow::DataService.setup_request(
      first_channel: 2,
      last_channel: 128,
      raw_data_type: Minknow::DataService::RawDataType::UNCALIBRATED,
      sample_minimum_chunk_size: 4096_u64,
      accepted_first_chunk_classifications: [1, 7],
    )
    setup = Minknow::DataService::LiveRequest.decode(request.encode).setup.not_nil!

    setup.first_channel.should eq(2_u32)
    setup.last_channel.should eq(128_u32)
    setup.raw_data_type.value.should eq(Minknow::DataService::RawDataType::UNCALIBRATED.value)
    setup.sample_minimum_chunk_size.should eq(4096_u64)
    setup.accepted_first_chunk_classifications.should eq([1, 7])
  end

  it "passes the protocol run ID to get_run_info" do
    channel = RecordingChannel.new
    ctx = GRPC::ClientContext.new
    service = Minknow::ProtocolService.new(channel, ctx)

    service.get_run_info("protocol-run")

    call = channel.calls.last
    call[0].should eq("minknow_api.protocol.ProtocolService")
    call[1].should eq("get_run_info")
    call[3].should be(ctx)
    MinknowApi::Protocol::GetRunInfoRequest.decode(call[2]).run_id.should eq("protocol-run")
  end

  it "passes the acquisition run ID to get_acquisition_info" do
    channel = RecordingChannel.new
    ctx = GRPC::ClientContext.new
    service = Minknow::AcquisitionService.new(channel, ctx)

    service.get_acquisition_info("acquisition-run")

    call = channel.calls.last
    call[0].should eq("minknow_api.acquisition.AcquisitionService")
    call[1].should eq("get_acquisition_info")
    call[3].should be(ctx)
    MinknowApi::Acquisition::GetAcquisitionRunInfoRequest.decode(call[2]).run_id.should eq("acquisition-run")
  end

  it "preserves fractional seconds in protocol wait timeouts" do
    channel = RecordingChannel.new
    run = Minknow::ProtocolService::RunInfo.new
    run.run_id = "current-run"
    channel.responses["get_current_protocol_run"] = run.encode
    service = Minknow::ProtocolService.new(channel, GRPC::ClientContext.new)

    service.wait_for_finished(1.25)

    call = channel.calls.last
    call[1].should eq("wait_for_finished")
    request = MinknowApi::Protocol::WaitForFinishedRequest.decode(call[2])
    request.timeout.should eq(1.25_f32)
    request.run_id.should eq("current-run")
  end

  it "uses the protobuf default when no protocol wait timeout is supplied" do
    channel = RecordingChannel.new
    service = Minknow::ProtocolService.new(channel, GRPC::ClientContext.new)

    service.wait_for_finished(run_id: "selected-run")

    request = MinknowApi::Protocol::WaitForFinishedRequest.decode(channel.calls.last[2])
    request.timeout.should eq(0.0_f32)
    request.run_id.should eq("selected-run")
    channel.calls.size.should eq(1)
  end

  it "requests calibration for all flow cell channels by default" do
    channel = RecordingChannel.new
    info = Minknow::DeviceService::FlowCellInfo.new
    info.channel_count = 3000_u32
    channel.responses["get_flow_cell_info"] = info.encode
    service = Minknow::DeviceService.new(channel, GRPC::ClientContext.new)

    service.calibration

    channel.calls.map { |call| call[1] }.should eq(["get_flow_cell_info", "get_calibration"])
    request = MinknowApi::Device::GetCalibrationRequest.decode(channel.calls.last[2])
    request.first_channel.should eq(1_u32)
    request.last_channel.should eq(3000_u32)
  end

  it "requests calibration for an explicit channel range without looking up the flow cell" do
    channel = RecordingChannel.new
    service = Minknow::DeviceService.new(channel, GRPC::ClientContext.new)

    service.calibration(first_channel: 2, last_channel: 128)

    channel.calls.size.should eq(1)
    request = MinknowApi::Device::GetCalibrationRequest.decode(channel.calls.last[2])
    request.first_channel.should eq(2_u32)
    request.last_channel.should eq(128_u32)
  end

  it "fails when secure port is missing" do
    manager = Minknow::Manager.new
    position = Minknow::FlowCellPosition.new("X3", "localhost")

    expect_raises(Minknow::MissingSecurePortError) do
      manager.connect(position)
    end
  end

  it "keeps local token lookups on the manager port when connecting to a position" do
    config = Minknow::ConnectionConfig.new(port: 9501)
    manager = Minknow::Manager.new(config)
    position = Minknow::FlowCellPosition.new("X4", "localhost", 9600)

    connection = manager.connect(position)

    connection.config.port.should eq(9600)
    connection.config.local_auth_lookup_config.port.should eq(9501)
    connection.config.with_port(9700).local_auth_lookup_config.port.should eq(9501)
    connection.config.local_auth_lookup_config.local_auth_enabled?.should be_false
  end

  it "preserves an explicit local token lookup port" do
    config = Minknow::ConnectionConfig.new(port: 9501, local_auth_lookup_port: 9502)

    config.with_port(9600).local_auth_lookup_config.port.should eq(9502)
  end

  it "ignores invalid local authentication token files" do
    ["[]", "null", "1", "\"value\"", "{\"token\":42}", "{}", "{invalid"].each do |payload|
      File.tempfile("minknow-auth") do |file|
        file.print(payload)
        file.flush

        config = TokenFileConfig.new(authentication_token: nil, protocol_token: nil, auto_local_auth: true)
        config.token_path = file.path
        config.effective_metadata.should be_empty
      end
    end
  end

  it "loads a valid local authentication token file" do
    File.tempfile("minknow-auth") do |file|
      file.print(%({"token":"local-token"}))
      file.flush

      config = TokenFileConfig.new(authentication_token: nil, protocol_token: nil, auto_local_auth: true)
      config.token_path = file.path
      config.effective_metadata.should eq({"local-auth" => "local-token"})
    end
  end
end

describe "service wrappers" do
  {% for entry in [
                    {:describe_host, MinknowApi::Manager::DescribeHostRequest},
                    {:get_version_info, MinknowApi::Manager::GetVersionInfoRequest},
                    {:get_disk_space_info, MinknowApi::Manager::GetDiskSpaceInfoRequest},
                    {:get_default_output_directories, MinknowApi::Instance::GetDefaultOutputDirectoriesRequest},
                    {:local_authentication_token_path, MinknowApi::Manager::LocalAuthenticationTokenPathRequest},
                  ] %}
    it {{"routes Manager #{entry[0]} with its request and context"}} do
      channel = RecordingChannel.new
      manager = RecordingManager.new
      manager.recording_channel = channel
      ctx = GRPC::ClientContext.new

      manager.{{entry[0].id}}(ctx)

      call = channel.calls.last
      call[0].should eq("minknow_api.manager.ManagerService")
      call[1].should eq({{entry[0].id.stringify}})
      {{entry[1]}}.decode(call[2]).should eq({{entry[1]}}.new)
      call[3].should be(ctx)
    end
  {% end %}

  it "decodes discovered positions from the manager stream" do
    channel = RecordingChannel.new
    response = MinknowApi::Manager::FlowCellPositionsResponse.new
    position = MinknowApi::Manager::FlowCellPosition.new
    position.name = "X1"
    ports = MinknowApi::Manager::FlowCellPosition::RpcPorts.new
    ports.secure = 9600_u32
    position.rpc_ports = ports
    response.positions = [position]
    channel.responses["flow_cell_positions"] = response.encode
    manager = RecordingManager.new(Minknow::ConnectionConfig.new(host: "manager.example"))
    manager.recording_channel = channel
    ctx = GRPC::ClientContext.new

    positions = manager.fetch_flow_cell_positions(ctx)

    positions.size.should eq(1)
    positions.first.name.should eq("X1")
    positions.first.host.should eq("manager.example")
    positions.first.secure_port.should eq(9600)
    channel.calls.last[1].should eq("flow_cell_positions")
    channel.calls.last[3].should be(ctx)
  end

  {% for entry in [
                    {:start_protocol, MinknowApi::Protocol::StartProtocolRequest},
                    {:stop_protocol, MinknowApi::Protocol::StopProtocolRequest},
                  ] %}
    it {{"passes the supplied #{entry[0]} request to the client"}} do
      channel = RecordingChannel.new
      ctx = GRPC::ClientContext.new
      service = Minknow::ProtocolService.new(channel, ctx)
      request = {{entry[1]}}.new

      service.{{entry[0].id}}(request)

      call = channel.calls.last
      call[1].should eq({{entry[0].id.stringify}})
      {{entry[1]}}.decode(call[2]).should eq(request)
      call[3].should be(ctx)
    end
  {% end %}

  {% for entry in [
                    {Minknow::InstanceService, :version_info, :get_version_info, MinknowApi::Instance::GetVersionInfoRequest},
                    {Minknow::InstanceService, :output_directories, :get_output_directories, MinknowApi::Instance::GetOutputDirectoriesRequest},
                    {Minknow::InstanceService, :default_output_directories, :get_default_output_directories, MinknowApi::Instance::GetDefaultOutputDirectoriesRequest},
                    {Minknow::InstanceService, :disk_space_info, :get_disk_space_info, MinknowApi::Instance::GetDiskSpaceInfoRequest},
                    {Minknow::InstanceService, :machine_id, :get_machine_id, MinknowApi::Instance::GetMachineIdRequest},
                    {Minknow::DeviceService, :device_info, :get_device_info, MinknowApi::Device::GetDeviceInfoRequest},
                    {Minknow::DeviceService, :device_state, :get_device_state, MinknowApi::Device::GetDeviceStateRequest},
                    {Minknow::DeviceService, :flow_cell_info, :get_flow_cell_info, MinknowApi::Device::GetFlowCellInfoRequest},
                    {Minknow::DeviceService, :channels_layout, :get_channels_layout, MinknowApi::Device::GetChannelsLayoutRequest},
                    {Minknow::DeviceService, :temperature, :get_temperature, MinknowApi::Device::GetTemperatureRequest},
                    {Minknow::AcquisitionService, :progress, :get_progress, MinknowApi::Acquisition::GetProgressRequest},
                    {Minknow::AcquisitionService, :current_status, :current_status, MinknowApi::Acquisition::CurrentStatusRequest},
                    {Minknow::ProtocolService, :pause_protocol, :pause_protocol, MinknowApi::Protocol::PauseProtocolRequest},
                    {Minknow::ProtocolService, :resume_protocol, :resume_protocol, MinknowApi::Protocol::ResumeProtocolRequest},
                    {Minknow::ProtocolService, :trigger_mux_scan, :trigger_mux_scan, MinknowApi::Protocol::TriggerMuxScanRequest},
                    {Minknow::ProtocolService, :current_protocol_run, :get_current_protocol_run, MinknowApi::Protocol::GetCurrentProtocolRunRequest},
                    {Minknow::ProtocolService, :list_protocol_runs, :list_protocol_runs, MinknowApi::Protocol::ListProtocolRunsRequest},
                    {Minknow::ProtocolService, :list_protocols, :list_protocols, MinknowApi::Protocol::ListProtocolsRequest},
                    {Minknow::ProtocolService, :context_info, :get_context_info, MinknowApi::Protocol::GetContextInfoRequest},
                    {Minknow::DataService, :data_types, :get_data_types, MinknowApi::Data::GetDataTypesRequest},
                  ] %}
    it {{"routes #{entry[0]} #{entry[1]} with its request and context"}} do
      channel = RecordingChannel.new
      ctx = GRPC::ClientContext.new(metadata: {"test-auth" => "token"})
      service = {{entry[0]}}.new(channel, ctx)

      service.{{entry[1].id}}

      channel.calls.size.should eq(1)
      call = channel.calls.last
      call[1].should eq({{entry[2].id.stringify}})
      {{entry[3]}}.decode(call[2]).should eq({{entry[3]}}.new)
      call[3].should be(ctx)
    end
  {% end %}

  {% for entry in [
                    {Minknow::DeviceService, :stream_device_state, MinknowApi::Device::StreamDeviceStateRequest},
                    {Minknow::DeviceService, :stream_flow_cell_info, MinknowApi::Device::StreamFlowCellInfoRequest},
                    {Minknow::DeviceService, :stream_temperature, MinknowApi::Device::StreamTemperatureRequest},
                    {Minknow::ProtocolService, :watch_current_protocol_run, MinknowApi::Protocol::WatchCurrentProtocolRunRequest},
                  ] %}
    it {{"opens #{entry[0]} #{entry[1]} with its request and context"}} do
      channel = RecordingChannel.new
      ctx = GRPC::ClientContext.new
      service = {{entry[0]}}.new(channel, ctx)

      service.{{entry[1].id}}.to_a.size.should eq(1)

      call = channel.calls.last
      call[1].should eq({{entry[1].id.stringify}})
      {{entry[2]}}.decode(call[2]).should eq({{entry[2]}}.new)
      call[3].should be(ctx)
    end
  {% end %}

  it "opens the live reads stream and sends setup and action requests" do
    channel = RecordingChannel.new
    ctx = GRPC::ClientContext.new
    service = Minknow::DataService.new(channel, ctx)
    stream = service.live_reads
    setup = Minknow::DataService.setup_request
    unblock = Minknow::DataService.unblock_action("unblock", 2_u32, "read-1", 0.25)
    stop = Minknow::DataService.stop_action("stop", 3_u32, "read-2")
    actions = Minknow::DataService.actions_request([unblock, stop])

    stream.send(setup)
    stream.send(actions)
    stream.close_send
    stream.to_a.size.should eq(1)

    call = channel.calls.last
    call[1].should eq("get_live_reads")
    call[3].should be(ctx)
    requests = channel.sent_requests.map { |bytes| Minknow::DataService::LiveRequest.decode(bytes) }
    requests.first.should eq(setup)
    requests.last.should eq(actions)
    decoded_actions = requests.last.actions.not_nil!.actions
    decoded_actions[0].action_id.should eq("unblock")
    decoded_actions[0].channel.should eq(2_u32)
    decoded_actions[0].id.should eq("read-1")
    decoded_actions[0].unblock.not_nil!.duration.should eq(0.25)
    decoded_actions[1].action_id.should eq("stop")
    decoded_actions[1].channel.should eq(3_u32)
    decoded_actions[1].id.should eq("read-2")
    decoded_actions[1].stop_further_data.should_not be_nil
  end
end
