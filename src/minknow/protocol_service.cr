require "../generated/minknow_api/protocol.pb.cr"
require "../generated/minknow_api/protocol.grpc.cr"

module Minknow
  # Wrapper around the MinKNOW Protocol gRPC service.
  #
  # Provides methods to start, stop, and inspect sequencing protocols.
  # Access via `Connection#protocol`.
  class ProtocolService
    alias RunInfo = MinknowApi::Protocol::ProtocolRunInfo
    alias StartResponse = MinknowApi::Protocol::StartProtocolResponse
    alias StopResponse = MinknowApi::Protocol::StopProtocolResponse
    alias ListRunsResponse = MinknowApi::Protocol::ListProtocolRunsResponse
    alias ListProtocolsResponse = MinknowApi::Protocol::ListProtocolsResponse
    alias ContextInfoResponse = MinknowApi::Protocol::GetContextInfoResponse

    def initialize(@channel : GRPC::Channel, @ctx : GRPC::ClientContext)
    end

    def client : MinknowApi::Protocol::ProtocolService::Client
      @client ||= MinknowApi::Protocol::ProtocolService::Client.new(@channel)
    end

    # Starts a protocol run. The *request* must be fully populated.
    def start_protocol(request : MinknowApi::Protocol::StartProtocolRequest) : StartResponse
      client.start_protocol(request, @ctx)
    end

    # Stops the currently running protocol.
    def stop_protocol(request : MinknowApi::Protocol::StopProtocolRequest = MinknowApi::Protocol::StopProtocolRequest.new) : StopResponse
      client.stop_protocol(request, @ctx)
    end

    # Pauses the currently running protocol.
    def pause_protocol : MinknowApi::Protocol::PauseProtocolResponse
      client.pause_protocol(MinknowApi::Protocol::PauseProtocolRequest.new, @ctx)
    end

    # Resumes a paused protocol.
    def resume_protocol : MinknowApi::Protocol::ResumeProtocolResponse
      client.resume_protocol(MinknowApi::Protocol::ResumeProtocolRequest.new, @ctx)
    end

    # Triggers a mux scan.
    def trigger_mux_scan : MinknowApi::Protocol::TriggerMuxScanResponse
      client.trigger_mux_scan(MinknowApi::Protocol::TriggerMuxScanRequest.new, @ctx)
    end

    # Returns info about the current protocol run.
    def current_protocol_run : RunInfo
      client.get_current_protocol_run(MinknowApi::Protocol::GetCurrentProtocolRunRequest.new, @ctx)
    end

    # Returns info about a specific protocol run by run_id.
    def get_run_info(run_id : String) : RunInfo
      client.get_run_info(
        MinknowApi::Protocol::GetRunInfoRequest.new(run_id: run_id),
        @ctx
      )
    end

    # Returns a list of all protocol runs.
    def list_protocol_runs : ListRunsResponse
      client.list_protocol_runs(MinknowApi::Protocol::ListProtocolRunsRequest.new, @ctx)
    end

    # Returns a list of available protocols.
    def list_protocols : ListProtocolsResponse
      client.list_protocols(MinknowApi::Protocol::ListProtocolsRequest.new, @ctx)
    end

    # Returns context info (user metadata) for the current run.
    def context_info : ContextInfoResponse
      client.get_context_info(MinknowApi::Protocol::GetContextInfoRequest.new, @ctx)
    end

    # Blocks until the current protocol finishes. *timeout_seconds* is optional.
    def wait_for_finished(timeout_seconds : Float64? = nil) : RunInfo
      req = MinknowApi::Protocol::WaitForFinishedRequest.new
      if t = timeout_seconds
        req = MinknowApi::Protocol::WaitForFinishedRequest.new(
          timeout: Google::Protobuf::Duration.new(seconds: t.to_i64)
        )
      end
      client.wait_for_finished(req, @ctx)
    end

    # Watches the current protocol run stream. Returns an iterable server stream.
    def watch_current_protocol_run : GRPC::ServerStream(MinknowApi::Protocol::ProtocolRunInfo)
      client.watch_current_protocol_run(MinknowApi::Protocol::WatchCurrentProtocolRunRequest.new, @ctx)
    end
  end
end
