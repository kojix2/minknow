require "../src/minknow"

host = ENV.fetch("MINKNOW_HOST", "localhost")
port = ENV.fetch("MINKNOW_PORT", "9501").to_i
tls = ENV.fetch("MINKNOW_TLS", "true") != "false"

manager = Minknow::Manager.new(
  Minknow::ConnectionConfig.new(host: host, port: port, tls: tls)
)

begin
  positions = manager.fetch_flow_cell_positions

  puts "positions=#{positions.size}"
  positions.each do |position|
    secure_port = position.secure_port.try(&.to_s) || "n/a"
    puts "#{position.name}\thost=#{position.host}\tsecure_port=#{secure_port}"
  end
rescue ex
  STDERR.puts "Failed to query MinKNOW Manager at #{host}:#{port} (tls=#{tls})"
  STDERR.puts ex.message || ex.class.name
  STDERR.puts "Check MINKNOW_HOST, MINKNOW_PORT, MINKNOW_TLS, MINKNOW_TRUSTED_CA, and MINKNOW_AUTH_TOKEN if the handshake or authentication fails."
  exit 1
end
