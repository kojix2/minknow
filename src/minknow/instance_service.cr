require "../generated/minknow_api/instance.pb.cr"
require "../generated/minknow_api/instance.grpc.cr"

module Minknow
  # Wrapper around the MinKNOW Instance gRPC service.
  #
  # Provides version and runtime information for a connected MinKNOW position.
  # Access via `Connection#instance`.
  class InstanceService
    alias VersionInfo = MinknowApi::Instance::GetVersionInfoResponse
    alias OutputDirectories = MinknowApi::Instance::OutputDirectories
    alias DiskSpaceInfo = MinknowApi::Instance::GetDiskSpaceInfoResponse
    alias MachineId = MinknowApi::Instance::GetMachineIdResponse

    def initialize(@channel : GRPC::Channel, @ctx : GRPC::ClientContext)
    end

    def client : MinknowApi::Instance::InstanceService::Client
      @client ||= MinknowApi::Instance::InstanceService::Client.new(@channel)
    end

    # Returns version information about this MinKNOW instance.
    def version_info : VersionInfo
      client.get_version_info(
        MinknowApi::Instance::GetVersionInfoRequest.new,
        @ctx
      )
    end

    # Returns the current output directories for this position.
    def output_directories : OutputDirectories
      client.get_output_directories(
        MinknowApi::Instance::GetOutputDirectoriesRequest.new,
        @ctx
      )
    end

    # Returns the default output directories for this position.
    def default_output_directories : OutputDirectories
      client.get_default_output_directories(
        MinknowApi::Instance::GetDefaultOutputDirectoriesRequest.new,
        @ctx
      )
    end

    # Returns disk space information for this position.
    def disk_space_info : DiskSpaceInfo
      client.get_disk_space_info(
        MinknowApi::Instance::GetDiskSpaceInfoRequest.new,
        @ctx
      )
    end

    # Returns the machine ID for this position.
    def machine_id : MachineId
      client.get_machine_id(
        MinknowApi::Instance::GetMachineIdRequest.new,
        @ctx
      )
    end
  end
end
