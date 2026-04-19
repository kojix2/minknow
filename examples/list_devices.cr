require "../src/minknow"

host = ENV.fetch("MINKNOW_HOST", "localhost")
port = ENV.fetch("MINKNOW_PORT", "9501").to_i
tls = ENV.fetch("MINKNOW_TLS", "true") != "false"

manager = Minknow::Manager.new(
  Minknow::ConnectionConfig.new(host: host, port: port, tls: tls)
)

positions = manager.fetch_flow_cell_positions

puts "positions=#{positions.size}"
positions.each do |position|
  secure_port = position.secure_port.try(&.to_s) || "n/a"
  puts "#{position.name}\thost=#{position.host}\tsecure_port=#{secure_port}"
end
