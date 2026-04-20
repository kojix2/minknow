require "../generated/minknow_api/data.pb.cr"
require "../generated/minknow_api/data.grpc.cr"

module Minknow
  # Wrapper around the MinKNOW Data gRPC service.
  #
  # Exposes the live-reads bidirectional stream and helper types for
  # building GetLiveReadsRequest messages.
  # Access via `Connection#data`.
  class DataService
    alias StreamSetup = MinknowApi::Data::GetLiveReadsRequest::StreamSetup
    alias Action = MinknowApi::Data::GetLiveReadsRequest::Action
    alias Actions = MinknowApi::Data::GetLiveReadsRequest::Actions
    alias LiveRequest = MinknowApi::Data::GetLiveReadsRequest
    alias LiveResponse = MinknowApi::Data::GetLiveReadsResponse
    alias ReadData = MinknowApi::Data::GetLiveReadsResponse::ReadData
    alias ActionResponse = MinknowApi::Data::GetLiveReadsResponse::ActionResponse
    alias RawDataType = MinknowApi::Data::GetLiveReadsRequest::RawDataType
    alias DataTypes = MinknowApi::Data::GetDataTypesResponse

    def initialize(@channel : GRPC::Channel, @ctx : GRPC::ClientContext)
    end

    def client : MinknowApi::Data::DataService::Client
      @client ||= MinknowApi::Data::DataService::Client.new(@channel)
    end

    # Opens a bidirectional live-reads stream.
    #
    # Returns a `GRPC::BidiCall` that you send `GetLiveReadsRequest` messages
    # into and receive `GetLiveReadsResponse` messages from.
    # The first message sent *must* contain a `StreamSetup`.
    def live_reads : GRPC::BidiCall(LiveRequest, LiveResponse)
      client.get_live_reads(@ctx)
    end

    # Returns the data types (signal calibration, dtype) for this device.
    def data_types : DataTypes
      client.get_data_types(MinknowApi::Data::GetDataTypesRequest.new, @ctx)
    end

    # Convenience: builds a setup-only request message.
    def self.setup_request(
      first_channel : Int32 = 1,
      last_channel : Int32 = 512,
      raw_data_type : RawDataType = RawDataType::CALIBRATED,
      sample_minimum_chunk_size : UInt64 = 0_u64,
      accepted_first_chunk_classifications : Array(Int32) = [] of Int32,
    ) : LiveRequest
      setup = StreamSetup.new(
        first_channel: first_channel.to_u32,
        last_channel: last_channel.to_u32,
        sample_minimum_chunk_size: sample_minimum_chunk_size,
        accepted_first_chunk_classifications: accepted_first_chunk_classifications,
      )
      setup.raw_data_type = Proto::OpenEnum(RawDataType).new(raw_data_type.value)
      req = LiveRequest.new
      req.setup = setup
      req
    end

    # Convenience: builds an actions-only request from a batch of actions.
    def self.actions_request(actions : Array(Action)) : LiveRequest
      req = LiveRequest.new
      req.actions = Actions.new(actions: actions)
      req
    end

    # Convenience: builds an unblock action.
    def self.unblock_action(
      action_id : String,
      channel : UInt32,
      read_id : String,
      duration : Float64 = 0.1,
    ) : Action
      action = Action.new(
        action_id: action_id,
        channel: channel,
      )
      action.id = read_id
      action.unblock = MinknowApi::Data::GetLiveReadsRequest::UnblockAction.new(duration: duration)
      action
    end

    # Convenience: builds a stop-further-data action.
    def self.stop_action(
      action_id : String,
      channel : UInt32,
      read_id : String,
    ) : Action
      action = Action.new(
        action_id: action_id,
        channel: channel,
      )
      action.id = read_id
      action.stop_further_data = MinknowApi::Data::GetLiveReadsRequest::StopFurtherData.new
      action
    end
  end
end
