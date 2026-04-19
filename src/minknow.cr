require "grpc"
require "proto"
require "./generated/minknow_api/manager.pb.cr"
require "./generated/minknow_api/manager.grpc.cr"

module Minknow
  VERSION = "0.1.0"

  class Error < Exception; end

  class MissingSecurePortError < Error; end

  class ConnectionConfig
    getter host : String
    getter port : Int32
    getter? tls : Bool
    getter metadata : Hash(String, String)

    def initialize(
      @host : String = "127.0.0.1",
      @port : Int32 = 9501,
      @tls : Bool = true,
      metadata : Hash(String, String)? = nil,
    )
      @metadata = metadata || {} of String => String
    end

    def with_port(port : Int32) : self
      self.class.new(host: host, port: port, tls: tls?, metadata: metadata.dup)
    end

    def address : String
      scheme = tls? ? "https" : "http"
      "#{scheme}://#{host}:#{port}"
    end

    def client_context : GRPC::ClientContext
      GRPC::ClientContext.new(metadata: metadata)
    end
  end

  class FlowCellPosition
    getter name : String
    getter host : String
    getter secure_port : Int32?

    def initialize(@name : String, @host : String, @secure_port : Int32? = nil)
    end

    def self.from_proto(position : MinknowApi::Manager::FlowCellPosition, host : String) : self
      secure_port = position.rpc_ports.try(&.secure)
      secure_port = nil if secure_port == 0
      new(position.name, host, secure_port.try(&.to_i))
    end

    def secure_port! : Int32
      secure_port || raise MissingSecurePortError.new("secure port is not available for #{name}")
    end
  end

  class ServiceHandle
    getter name : Symbol
    getter config : ConnectionConfig

    def initialize(@name : Symbol, @config : ConnectionConfig)
    end
  end

  class Connection
    getter position : FlowCellPosition
    getter config : ConnectionConfig

    def initialize(@position : FlowCellPosition, @config : ConnectionConfig)
    end

    def endpoint : String
      "#{config.host}:#{config.port}"
    end

    def instance : ServiceHandle
      @instance ||= ServiceHandle.new(:instance, config)
    end

    def data : ServiceHandle
      @data ||= ServiceHandle.new(:data, config)
    end

    def device : ServiceHandle
      @device ||= ServiceHandle.new(:device, config)
    end
  end

  class Manager
    getter config : ConnectionConfig

    def initialize(@config : ConnectionConfig = ConnectionConfig.new)
      @positions = [] of FlowCellPosition
    end

    def channel : GRPC::Channel
      @channel ||= GRPC::Channel.new(config.address)
    end

    def client : MinknowApi::Manager::ManagerService::Client
      @client ||= MinknowApi::Manager::ManagerService::Client.new(channel)
    end

    def flow_cell_positions : Array(FlowCellPosition)
      @positions.dup
    end

    def fetch_flow_cell_positions(ctx : GRPC::ClientContext = config.client_context) : Array(FlowCellPosition)
      request = MinknowApi::Manager::FlowCellPositionsRequest.new
      stream = client.flow_cell_positions(request, ctx)
      positions = [] of FlowCellPosition

      stream.each do |response|
        response.positions.each do |position|
          positions << FlowCellPosition.from_proto(position, config.host)
        end
      end

      positions
    end

    def register_position(position : FlowCellPosition) : FlowCellPosition
      @positions << position
      position
    end

    def connect(position : FlowCellPosition) : Connection
      Connection.new(position, config.with_port(position.secure_port!))
    end
  end
end
