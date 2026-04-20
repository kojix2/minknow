require "colorize"
require "option_parser"
require "../src/minknow"
require "../src/generated/minknow_api/protocol.pb.cr"
require "../src/generated/minknow_api/protocol.grpc.cr"
require "../src/generated/minknow_api/ui/sequencing_run/presets.pb.cr"
require "../src/generated/minknow_api/ui/sequencing_run/presets.grpc.cr"

def parse_bool(value : String, name : String) : Bool
  case value.downcase
  when "1", "true", "yes", "on"
    true
  when "0", "false", "no", "off"
    false
  else
    raise ArgumentError.new("#{name} must be true/false (or 1/0), got: #{value}")
  end
end

host = ENV.fetch("MINKNOW_HOST", "localhost")
port = ENV.fetch("MINKNOW_PORT", "9501").to_i
tls = parse_bool(ENV.fetch("MINKNOW_TLS", "true"), "MINKNOW_TLS")
create_simulated_devices = parse_bool(ENV.fetch("MINKNOW_CREATE_SIMULATED", "false"), "MINKNOW_CREATE_SIMULATED")
flow_cell_code = ENV["MINKNOW_FLOW_CELL_PRODUCT_CODE"]?
sequencing_kit = ENV["MINKNOW_SEQUENCING_KIT"]?
preset_id = ENV.fetch("MINKNOW_PRESET_ID", "standard_sequencing")
protocol_limit = ENV.fetch("MINKNOW_PROTOCOL_LIMIT", "5").to_i

OptionParser.parse do |parser|
  parser.banner = "Usage: crystal run examples/simulated_protocol_preset_workflow.cr -- [options]"

  parser.on("--host HOST", "Manager host (default: MINKNOW_HOST or localhost)") { |value| host = value }
  parser.on("--port PORT", "Manager port (default: MINKNOW_PORT or 9501)") { |value| port = value.to_i }
  parser.on("--tls BOOL", "Use TLS true/false (default: MINKNOW_TLS or true)") { |value| tls = parse_bool(value, "--tls") }
  parser.on("--create-simulated BOOL", "Create simulated devices true/false (default: MINKNOW_CREATE_SIMULATED or false)") do |value|
    create_simulated_devices = parse_bool(value, "--create-simulated")
  end
  parser.on("--flow-cell-code CODE", "Filter find_protocols by flow cell product code") { |value| flow_cell_code = value }
  parser.on("--sequencing-kit KIT", "Filter find_protocols by sequencing kit") { |value| sequencing_kit = value }
  parser.on("--preset-id ID", "Preset ID for preset/get_start_protocol (default: MINKNOW_PRESET_ID or standard_sequencing)") { |value| preset_id = value }
  parser.on("--protocol-limit N", "Maximum protocols to print per section (default: MINKNOW_PROTOCOL_LIMIT or 5)") { |value| protocol_limit = value.to_i }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit 0
  end
end

if protocol_limit <= 0
  raise ArgumentError.new("--protocol-limit must be > 0")
end

LABEL_WIDTH = 34

def section(title : String) : Nil
  puts title.colorize.green
end

def row(label : String, value : String) : Nil
  puts "  %-#{LABEL_WIDTH}s %s" % {"#{label}:", value}
end

def bool_word(value : Bool) : String
  value ? "yes" : "no"
end

def value_or_any(value : String?) : String
  value || "(any)"
end

def format_tag_value(value : MinknowApi::Protocol::ProtocolInfo::TagValue) : String
  case value.tag_value_case
  when .string_value?
    value.string_value
  when .bool_value?
    value.bool_value.to_s
  when .int_value?
    value.int_value.to_s
  when .double_value?
    value.double_value.to_s
  when .array_value?
    value.array_value
  when .object_value?
    value.object_value
  else
    "<empty>"
  end
end

def simulated_device_specs : Array(Tuple(String, MinknowApi::Manager::SimulatedDeviceType))
  [
    {"MS12345", MinknowApi::Manager::SimulatedDeviceType::SIMULATED_MINION},
    {"GS12345", MinknowApi::Manager::SimulatedDeviceType::SIMULATED_PROMETHION},
    {"P2S_12345-A", MinknowApi::Manager::SimulatedDeviceType::SIMULATED_P2},
  ]
end

def add_simulated_devices(manager : Minknow::Manager) : Array(String)
  created = [] of String
  ctx = manager.config.client_context

  simulated_device_specs.each do |name, type|
    request = MinknowApi::Manager::AddSimulatedDeviceRequest.new
    request.name = name
    request.type_ = Proto::OpenEnum(MinknowApi::Manager::SimulatedDeviceType).new(type.to_i)

    begin
      manager.client.add_simulated_device(request, ctx)
      created << name
      row("simulated device", "created #{name} (#{type})")
    rescue ex
      row("simulated device", "failed #{name} (#{type}): #{ex.class.name}")
    end
  end

  created
end

def choose_positions(positions : Array(Minknow::FlowCellPosition), preferred : Array(String)) : Array(Minknow::FlowCellPosition)
  return positions if preferred.empty?

  selected = positions.select { |position| preferred.includes?(position.name) }
  selected.empty? ? positions : selected
end

def list_protocols_for_position(manager : Minknow::Manager, position : Minknow::FlowCellPosition, protocol_limit : Int32) : Nil
  connection = manager.connect(position)
  channel = connection.config.channel
  protocol_client = MinknowApi::Protocol::ProtocolService::Client.new(channel)
  ctx = connection.config.client_context

  request = MinknowApi::Protocol::ListProtocolsRequest.new
  request.force_reload = true

  response = protocol_client.list_protocols(request, ctx)
  limited = response.protocols.first(protocol_limit)

  section("Protocols on #{position.name}")
  row("endpoint", "#{connection.config.host}:#{connection.config.port}")
  row("available", response.protocols.size.to_s)

  if limited.empty?
    row("result", "no protocols returned")
  else
    limited.each_with_index do |protocol, index|
      row("protocol #{index + 1}", "#{protocol.name} (#{protocol.identifier})")
      if protocol.tags.empty?
        row("tags", "none")
      else
        sample = protocol.tags.first(3).map { |key, value| "#{key}=#{format_tag_value(value)}" }
        row("tags", sample.join(", "))
      end
    end
  end

  puts
ensure
  channel.try(&.close)
end

def find_protocols(manager : Minknow::Manager, flow_cell_code : String?, sequencing_kit : String?) : MinknowApi::Manager::FindProtocolsResponse
  request = MinknowApi::Manager::FindProtocolsRequest.new
  request.experiment_type = Proto::OpenEnum(MinknowApi::Manager::ExperimentType).new(
    MinknowApi::Manager::ExperimentType::SEQUENCING.to_i
  )
  request.flow_cell_product_code = flow_cell_code.to_s if flow_cell_code
  request.sequencing_kit = sequencing_kit.to_s if sequencing_kit
  manager.client.find_protocols(request, manager.config.client_context)
end

def preset_type_from_id(preset_id : String) : MinknowApi::Ui::SequencingRun::Presets::PresetType
  preset_type = MinknowApi::Ui::SequencingRun::Presets::PresetType.new
  preset_type.preset_id = preset_id
  preset_type
end

manager = Minknow::Manager.new(
  Minknow::ConnectionConfig.new(host: host, port: port, tls: tls)
)

begin
  section("Workflow")
  row("manager", "#{host}:#{port}")
  row("tls", bool_word(tls))
  row("create simulated devices", bool_word(create_simulated_devices))
  row("find_protocols flow cell", value_or_any(flow_cell_code))
  row("find_protocols sequencing kit", value_or_any(sequencing_kit))
  row("preset id", preset_id)
  puts

  created_devices = [] of String
  if create_simulated_devices
    section("Step 1: Add simulated devices")
    created_devices = add_simulated_devices(manager)
    puts
  end

  section("Step 2: Enumerate positions")
  positions = manager.fetch_flow_cell_positions
  row("discovered positions", positions.size.to_s)
  selected_positions = choose_positions(positions, created_devices)
  row("positions for protocol listing", selected_positions.size.to_s)
  puts

  selected_positions.each do |position|
    begin
      list_protocols_for_position(manager, position, protocol_limit)
    rescue ex
      section("Protocols on #{position.name}")
      row("error", "#{ex.class.name}: #{ex.message}")
      puts
    end
  end

  section("Step 3: Manager find_protocols")
  compatible = find_protocols(manager, flow_cell_code, sequencing_kit)
  row("compatible protocol count", compatible.protocols.size.to_s)
  compatible.protocols.first(protocol_limit).each_with_index do |protocol, index|
    row("candidate #{index + 1}", protocol.identifier)
  end
  puts

  section("Step 4: Presets service")
  presets_client = MinknowApi::Ui::SequencingRun::Presets::PresetsService::Client.new(manager.channel)
  list_response = presets_client.list_presets(
    MinknowApi::Ui::SequencingRun::Presets::ListPresetsRequest.new,
    manager.config.client_context
  )
  row("available presets", list_response.preset_info_list.size.to_s)

  preset_type = preset_type_from_id(preset_id)

  get_preset_request = MinknowApi::Ui::SequencingRun::Presets::GetPresetRequest.new
  get_preset_request.preset_type = preset_type
  get_preset_request.return_type = Proto::OpenEnum(MinknowApi::Ui::SequencingRun::Presets::GetPresetRequest::ReturnType).new(
    MinknowApi::Ui::SequencingRun::Presets::GetPresetRequest::ReturnType::PRESET_OBJECT.to_i
  )

  begin
    get_preset_response = presets_client.get_preset(get_preset_request, manager.config.client_context)
    found = get_preset_response.preset_type.try(&.data_case) != MinknowApi::Ui::SequencingRun::Presets::PresetType::DataCase::NONE
    row("get_preset", found ? "found #{preset_id}" : "not found")
  rescue ex
    row("get_preset", "failed: #{ex.class.name}")
  end

  get_start_request = MinknowApi::Ui::SequencingRun::Presets::GetStartProtocolRequest.new
  get_start_request.preset_type = preset_type

  begin
    presets_client.get_start_protocol(get_start_request, manager.config.client_context)
    row("get_start_protocol", "resolved for #{preset_id}")
  rescue ex
    row("get_start_protocol", "failed: #{ex.class.name}")
  end
rescue ex
  STDERR.puts "Workflow failed at #{host}:#{port} (tls=#{tls})"
  STDERR.puts ex.message || ex.class.name
  STDERR.puts "Check MINKNOW_HOST, MINKNOW_PORT, MINKNOW_TLS, MINKNOW_TRUSTED_CA, MINKNOW_AUTH_TOKEN, MINKNOW_API_CLIENT_CERTIFICATE_CHAIN, and MINKNOW_API_CLIENT_KEY."
  exit 1
end
