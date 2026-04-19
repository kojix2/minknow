require "grpc"
require "json"
require "proto"
require "./generated/minknow_api/manager.pb.cr"
require "./generated/minknow_api/manager.grpc.cr"

module Minknow
  VERSION = "0.1.0"

  class Error < Exception; end

  class MissingSecurePortError < Error; end

  class ConnectionConfig
    DEFAULT_LINUX_CA_PATHS = [
      "/data/rpc-certs/minknow/ca.crt",
      "/var/lib/minknow/data/rpc-certs/minknow/ca.crt",
    ]

    DEFAULT_MACOS_CA_PATHS = [
      "/Library/MinKNOW/data/rpc-certs/minknow/ca.crt",
    ]

    DEFAULT_WINDOWS_CA_PATHS = [
      "C:/data/rpc-certs/minknow/ca.crt",
    ]

    getter host : String
    getter port : Int32
    getter? tls : Bool
    getter metadata : Hash(String, String)
    getter ca_certificate_path : String?
    getter authentication_token : String?
    getter protocol_token : String?
    getter auto_local_auth : Bool?
    getter local_auth_lookup_port : Int32?

    def initialize(
      @host : String = "127.0.0.1",
      @port : Int32 = 9501,
      @tls : Bool = true,
      metadata : Hash(String, String)? = nil,
      @ca_certificate_path : String? = nil,
      @authentication_token : String? = ENV["MINKNOW_AUTH_TOKEN"]?,
      @protocol_token : String? = ENV["PROTOCOL_TOKEN"]?,
      @auto_local_auth : Bool? = nil,
      @local_auth_lookup_port : Int32? = nil,
    )
      @metadata = metadata || {} of String => String
    end

    def with_port(port : Int32) : self
      self.class.new(
        host: host,
        port: port,
        tls: tls?,
        metadata: metadata.dup,
        ca_certificate_path: ca_certificate_path,
        authentication_token: authentication_token,
        protocol_token: protocol_token,
        auto_local_auth: auto_local_auth,
        local_auth_lookup_port: local_auth_lookup_port,
      )
    end

    def address : String
      scheme = tls? ? "https" : "http"
      "#{scheme}://#{host}:#{port}"
    end

    def client_context : GRPC::ClientContext
      GRPC::ClientContext.new(metadata: effective_metadata)
    end

    def channel : GRPC::Channel
      GRPC::Channel.new(address, tls_context: tls_context)
    end

    def local_auth_lookup_config : self
      lookup_port = local_auth_lookup_port || port
      self.class.new(
        host: host,
        port: lookup_port,
        tls: true,
        metadata: metadata.dup,
        ca_certificate_path: ca_certificate_path,
        authentication_token: nil,
        protocol_token: nil,
        auto_local_auth: false,
        local_auth_lookup_port: lookup_port,
      )
    end

    def local_auth_lookup_port! : Int32
      local_auth_lookup_port || port
    end

    def localhost? : Bool
      case host.downcase
      when "localhost", "localhost.localdomain", "127.0.0.1", "::1"
        true
      else
        false
      end
    end

    def local_auth_enabled? : Bool
      override = ENV["MINKNOW_API_USE_LOCAL_TOKEN"]?
      if value = auto_local_auth
        return value
      end

      case override.try(&.downcase)
      when nil
        localhost?
      when "", "0", "no", "false"
        false
      else
        true
      end
    end

    def effective_metadata : Hash(String, String)
      combined = metadata.dup

      if token = authentication_token
        combined["local-auth"] = token
      elsif local_auth_enabled?
        if token = local_auth_token
          combined["local-auth"] = token
        end
      end

      if token = protocol_token
        combined["protocol-auth"] = token
      end

      combined
    end

    def tls_context : OpenSSL::SSL::Context::Client?
      return nil unless tls?

      OpenSSL::SSL::Context::Client.new.tap do |context|
        context.alpn_protocol = "h2"
        if cert_path = resolved_ca_certificate_path
          context.ca_certificates = cert_path
          context.verify_mode = OpenSSL::SSL::VerifyMode::PEER
        end
      end
    end

    private def local_auth_token : String?
      token_path = local_auth_token_path
      return unless token_path
      return unless File.file?(token_path)

      payload = JSON.parse(File.read(token_path))
      payload["token"]?.try(&.as_s?)
    rescue JSON::ParseException
      nil
    rescue IO::Error
      nil
    end

    private def local_auth_token_path : String?
      lookup_channel = local_auth_lookup_config.channel
      lookup_client = MinknowApi::Manager::ManagerService::Client.new(lookup_channel)
      request = MinknowApi::Manager::LocalAuthenticationTokenPathRequest.new
      response = lookup_client.local_authentication_token_path(request)
      path = response.path
      path.empty? ? nil : path
    rescue GRPC::StatusError
      nil
    ensure
      lookup_channel.try(&.close)
    end

    private def resolved_ca_certificate_path : String?
      explicit = ca_certificate_path || ENV["MINKNOW_TRUSTED_CA"]?
      return explicit if explicit && File.file?(explicit)

      default_ca_certificate_paths.find do |candidate|
        File.file?(candidate)
      end
    end

    private def default_ca_certificate_paths : Array(String)
      {% if flag?(:win32) %}
        DEFAULT_WINDOWS_CA_PATHS
      {% elsif flag?(:darwin) %}
        DEFAULT_MACOS_CA_PATHS
      {% else %}
        DEFAULT_LINUX_CA_PATHS
      {% end %}
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

    @channel : GRPC::Channel?

    def initialize(@config : ConnectionConfig = ConnectionConfig.new)
      @positions = [] of FlowCellPosition
    end

    def channel : GRPC::Channel
      @channel ||= config.channel
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

    def describe_host(ctx : GRPC::ClientContext = config.client_context) : MinknowApi::Manager::DescribeHostResponse
      request = MinknowApi::Manager::DescribeHostRequest.new
      client.describe_host(request, ctx)
    end

    def get_version_info(ctx : GRPC::ClientContext = config.client_context) : MinknowApi::Instance::GetVersionInfoResponse
      request = MinknowApi::Manager::GetVersionInfoRequest.new
      client.get_version_info(request, ctx)
    end

    def get_disk_space_info(ctx : GRPC::ClientContext = config.client_context) : MinknowApi::Manager::GetDiskSpaceInfoResponse
      request = MinknowApi::Manager::GetDiskSpaceInfoRequest.new
      client.get_disk_space_info(request, ctx)
    end

    def get_default_output_directories(ctx : GRPC::ClientContext = config.client_context) : MinknowApi::Instance::OutputDirectories
      request = MinknowApi::Instance::GetDefaultOutputDirectoriesRequest.new
      client.get_default_output_directories(request, ctx)
    end

    def local_authentication_token_path(ctx : GRPC::ClientContext = GRPC::ClientContext.new) : String?
      request = MinknowApi::Manager::LocalAuthenticationTokenPathRequest.new
      response = client.local_authentication_token_path(request, ctx)
      path = response.path
      path.empty? ? nil : path
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
