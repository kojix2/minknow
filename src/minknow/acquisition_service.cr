require "../generated/minknow_api/acquisition.pb.cr"
require "../generated/minknow_api/acquisition.grpc.cr"

module Minknow
  # Wrapper around the MinKNOW Acquisition gRPC service.
  #
  # Provides acquisition progress and run status queries.
  # Access via `Connection#acquisition`.
  class AcquisitionService
    alias ProgressResponse = MinknowApi::Acquisition::GetProgressResponse
    alias RawPerChannel = MinknowApi::Acquisition::GetProgressResponse::RawPerChannel
    alias RunInfo = MinknowApi::Acquisition::AcquisitionRunInfo
    alias CurrentStatus = MinknowApi::Acquisition::CurrentStatusResponse

    def initialize(@channel : GRPC::Channel, @ctx : GRPC::ClientContext)
    end

    def client : MinknowApi::Acquisition::AcquisitionService::Client
      @client ||= MinknowApi::Acquisition::AcquisitionService::Client.new(@channel)
    end

    # Returns acquisition progress.
    # The `raw_per_channel` field holds `.acquired` and `.processed` sample counts.
    def progress : ProgressResponse
      client.get_progress(MinknowApi::Acquisition::GetProgressRequest.new, @ctx)
    end

    # Returns the current acquisition status.
    def current_status : CurrentStatus
      client.get_current_status(MinknowApi::Acquisition::GetCurrentStatusRequest.new, @ctx)
    end

    # Returns info about a specific acquisition run by run_id.
    def get_acquisition_info(run_id : String) : RunInfo
      client.get_acquisition_info(
        MinknowApi::Acquisition::GetAcquisitionRunInfoRequest.new(run_id: run_id),
        @ctx
      )
    end
  end
end
