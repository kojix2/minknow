require "colorize"
require "../src/minknow"

host = ENV.fetch("MINKNOW_HOST", "localhost")
port = ENV.fetch("MINKNOW_PORT", "9501").to_i
tls = ENV.fetch("MINKNOW_TLS", "true") != "false"
LABEL_WIDTH = 32

def print_section(title : String) : Nil
  puts title.colorize.green
end

def print_row(label : String, value : String) : Nil
  puts "  %-#{LABEL_WIDTH}s %s" % {"#{label}:", value}
end

def value_or_na(value : String) : String
  value.empty? ? "n/a" : value
end

def yes_no(value : Bool) : String
  value ? "yes" : "no"
end

def human_bytes(value : UInt64) : String
  return "0 B" if value == 0

  units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
  size = value.to_f64
  unit_index = 0

  while size >= 1024 && unit_index < units.size - 1
    size /= 1024
    unit_index += 1
  end

  "%.1f %s" % {size, units[unit_index]}
end

def human_rate(value : Int64) : String
  return "n/a" if value <= 0

  "#{human_bytes(value.to_u64)}/s"
end

def percent(available : UInt64, capacity : UInt64) : String
  return "n/a" if capacity == 0

  "%.1f%%" % {(available.to_f64 / capacity.to_f64) * 100.0}
end

def format_version(response : MinknowApi::Instance::GetVersionInfoResponse) : String
  version = response.minknow
  return "n/a" unless version

  version.full.empty? ? "#{version.major}.#{version.minor}.#{version.patch}" : version.full
end

def format_distribution_status(status : Proto::OpenEnum(MinknowApi::Instance::GetVersionInfoResponse::DistributionStatus)) : String
  case status.raw
  when 1 then "stable"
  when 2 then "unstable"
  when 3 then "modified"
  else        "unknown"
  end
end

def format_installation_type(type : Proto::OpenEnum(MinknowApi::Instance::GetVersionInfoResponse::InstallationType)) : String
  case type.raw
  when 0 then "ONT"
  when 1 then "NC"
  when 2 then "PROD"
  when 3 then "Q_RELEASE"
  when 4 then "Oxford Nanopore Diagnostic"
  else        "unknown"
  end
end

def format_usb_availability(status : Proto::OpenEnum(MinknowApi::Manager::DescribeHostResponse::HostUsbSequencerAvailability)) : String
  case status.raw
  when 1 then "driver_disabled"
  when 2 then "available"
  else        "unavailable"
  end
end

def format_basecalling_availability(status : Proto::OpenEnum(MinknowApi::Manager::DescribeHostResponse::BasecallingAvailability)) : String
  case status.raw
  when 0 then "available"
  when 1 then "unavailable"
  when 2 then "bad_configuration"
  when 3 then "attempting_recovery"
  else        "unknown"
  end
end

def format_basecalling_hardware(hardware : MinknowApi::Manager::DescribeHostResponse::BasecallerSubstrate?) : String
  return "n/a" unless hardware
  return "CPU" unless hardware.is_gpu
  return "GPU" if hardware.gpus.empty?

  "GPU (#{hardware.gpus.join(", ")})"
end

def format_position(position : Minknow::FlowCellPosition) : String
  if secure_port = position.secure_port
    "#{position.name} (#{position.host}:#{secure_port})"
  else
    position.name
  end
end

manager = Minknow::Manager.new(
  Minknow::ConnectionConfig.new(host: host, port: port, tls: tls)
)

begin
  host_info = manager.describe_host
  version_info = manager.get_version_info
  output_directories = manager.get_default_output_directories
  disk_info = manager.get_disk_space_info
  positions = manager.fetch_flow_cell_positions

  print_section("MinKNOW Manager")
  print_row("endpoint", "#{host}:#{port}")
  print_row("tls", yes_no(tls))
  puts
  print_section("Host")
  print_row("product code", value_or_na(host_info.product_code))
  print_row("description", value_or_na(host_info.description))
  print_row("serial", value_or_na(host_info.serial))
  print_row("network name", value_or_na(host_info.network_name))
  print_row("needs association", yes_no(host_info.needs_association))
  print_row("offline sequencing", yes_no(host_info.can_sequence_offline))
  print_row("USB device access", format_usb_availability(host_info.can_connect_to_usb_device))
  print_row("basecalling", format_basecalling_availability(host_info.can_basecall))
  print_row("active basecalling hardware", format_basecalling_hardware(host_info.current_basecalling_hardware))
  hw = host_info.available_basecalling_hardware
  print_row("available basecalling hardware", hw.empty? ? "n/a" : hw.map { |h| format_basecalling_hardware(h) }.join(" | "))
  puts
  print_section("Version")
  print_row("minknow", format_version(version_info))
  print_row("distribution version", value_or_na(version_info.distribution_version))
  print_row("distribution status", format_distribution_status(version_info.distribution_status))
  print_row("installation type", format_installation_type(version_info.installation_type))
  print_row("bream", value_or_na(version_info.bream))
  print_row("protocol configuration", value_or_na(version_info.protocol_configuration))
  print_row("basecaller build", value_or_na(version_info.basecaller_build_version))
  print_row("basecaller connected", value_or_na(version_info.basecaller_connected_version))
  puts
  print_section("Flow cell positions")
  print_row("count", positions.size.to_s)
  if positions.empty?
    print_row("positions", "none")
  else
    positions.each_with_index do |pos, i|
      print_row(i.zero? ? "positions" : "", format_position(pos))
    end
  end
  puts
  print_section("Output directories")
  print_row("output", value_or_na(output_directories.output))
  print_row("log", value_or_na(output_directories.log))
  print_row("reads", value_or_na(output_directories.reads))
  puts
  print_section("Disk space")
  if disk_info.filesystem_disk_space_info.empty?
    print_row("status", "no filesystem information available")
  else
    disk_info.filesystem_disk_space_info.each do |filesystem|
      print_row("filesystem", value_or_na(filesystem.filesystem_id))
      print_row("available", "#{human_bytes(filesystem.bytes_available)} (#{percent(filesystem.bytes_available, filesystem.bytes_capacity)} free)")
      print_row("capacity", human_bytes(filesystem.bytes_capacity))
      print_row("bytes to stop cleanly", human_bytes(filesystem.bytes_to_stop_cleanly))
      print_row("alert threshold", human_bytes(filesystem.bytes_when_alert_issued))
      print_row("write rate", human_rate(filesystem.bytes_per_second))
      print_row("stored file types", value_or_na(filesystem.file_types_stored.join(", ")))
      print_row("recommend alert", yes_no(filesystem.recommend_alert))
      print_row("recommend stop", yes_no(filesystem.recommend_stop))
      puts
    end
  end
rescue ex
  STDERR.puts "Failed to query MinKNOW Manager at #{host}:#{port} (tls=#{tls})"
  STDERR.puts ex.message || ex.class.name
  STDERR.puts "Check MINKNOW_HOST, MINKNOW_PORT, MINKNOW_TLS, MINKNOW_TRUSTED_CA, MINKNOW_AUTH_TOKEN, MINKNOW_API_CLIENT_CERTIFICATE_CHAIN, and MINKNOW_API_CLIENT_KEY if the handshake or authentication fails."
  exit 1
end
