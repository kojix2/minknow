require "../src/minknow"

host = ENV.fetch("MINKNOW_HOST", "localhost")
port = ENV.fetch("MINKNOW_PORT", "9501").to_i
tls = ENV.fetch("MINKNOW_TLS", "true") != "false"

def value_or_na(value : String) : String
  value.empty? ? "n/a" : value
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

def version_string(response : MinknowApi::Instance::GetVersionInfoResponse) : String
  version = response.minknow
  return "n/a" unless version

  version.full.empty? ? "#{version.major}.#{version.minor}.#{version.patch}" : version.full
end

manager = Minknow::Manager.new(
  Minknow::ConnectionConfig.new(host: host, port: port, tls: tls)
)

begin
  host_info = manager.describe_host
  version_info = manager.get_version_info
  output_directories = manager.get_default_output_directories
  disk_info = manager.get_disk_space_info

  puts "MinKNOW Manager"
  puts "  endpoint: #{host}:#{port}"
  puts "  tls: #{tls}"
  puts
  puts "Host"
  puts "  product_code: #{value_or_na(host_info.product_code)}"
  puts "  description: #{value_or_na(host_info.description)}"
  puts "  serial: #{value_or_na(host_info.serial)}"
  puts "  network_name: #{value_or_na(host_info.network_name)}"
  puts "  needs_association: #{host_info.needs_association}"
  puts "  can_sequence_offline: #{host_info.can_sequence_offline}"
  puts "  can_connect_to_usb_device: #{host_info.can_connect_to_usb_device}"
  puts "  can_basecall: #{host_info.can_basecall}"
  puts
  puts "Version"
  puts "  minknow: #{version_string(version_info)}"
  puts "  distribution_version: #{value_or_na(version_info.distribution_version)}"
  puts "  bream: #{value_or_na(version_info.bream)}"
  puts "  protocol_configuration: #{value_or_na(version_info.protocol_configuration)}"
  puts "  basecaller_build_version: #{value_or_na(version_info.basecaller_build_version)}"
  puts "  basecaller_connected_version: #{value_or_na(version_info.basecaller_connected_version)}"
  puts
  puts "Output directories"
  puts "  output: #{value_or_na(output_directories.output)}"
  puts "  log: #{value_or_na(output_directories.log)}"
  puts "  reads: #{value_or_na(output_directories.reads)}"
  puts
  puts "Disk space"
  if disk_info.filesystem_disk_space_info.empty?
    puts "  no filesystem information available"
  else
    disk_info.filesystem_disk_space_info.each do |filesystem|
      puts "  #{value_or_na(filesystem.filesystem_id)}"
      puts "    available: #{human_bytes(filesystem.bytes_available)}"
      puts "    capacity: #{human_bytes(filesystem.bytes_capacity)}"
      puts "    alert: #{filesystem.recommend_alert}"
      puts "    stop: #{filesystem.recommend_stop}"
    end
  end
rescue ex
  STDERR.puts "Failed to query MinKNOW Manager at #{host}:#{port} (tls=#{tls})"
  STDERR.puts ex.message || ex.class.name
  STDERR.puts "Check MINKNOW_HOST, MINKNOW_PORT, MINKNOW_TLS, MINKNOW_TRUSTED_CA, and MINKNOW_AUTH_TOKEN if the handshake or authentication fails."
  exit 1
end
