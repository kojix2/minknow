require "../generated/minknow_api/device.pb.cr"
require "../generated/minknow_api/device.grpc.cr"

module Minknow
  # Wrapper around the MinKNOW Device gRPC service.
  #
  # Provides device-independent hardware queries: device info, state, flow cell
  # info, calibration and temperature. Access via `Connection#device`.
  class DeviceService
    alias DeviceInfo = MinknowApi::Device::GetDeviceInfoResponse
    alias DeviceState = MinknowApi::Device::GetDeviceStateResponse
    alias FlowCellInfo = MinknowApi::Device::GetFlowCellInfoResponse
    alias ChannelsLayout = MinknowApi::Device::GetChannelsLayoutResponse
    alias CalibrationResponse = MinknowApi::Device::GetCalibrationResponse
    alias Temperature = MinknowApi::Device::GetTemperatureResponse

    def initialize(@channel : GRPC::Channel, @ctx : GRPC::ClientContext)
    end

    def client : MinknowApi::Device::DeviceService::Client
      @client ||= MinknowApi::Device::DeviceService::Client.new(@channel)
    end

    # Returns general information about the device attached to this position.
    def get_device_info : DeviceInfo
      client.get_device_info(
        MinknowApi::Device::GetDeviceInfoRequest.new,
        @ctx
      )
    end

    # Returns the current device state (connected / ready).
    def get_device_state : DeviceState
      client.get_device_state(
        MinknowApi::Device::GetDeviceStateRequest.new,
        @ctx
      )
    end

    # Returns information about the flow cell loaded in this position.
    def get_flow_cell_info : FlowCellInfo
      client.get_flow_cell_info(
        MinknowApi::Device::GetFlowCellInfoRequest.new,
        @ctx
      )
    end

    # Returns the channel layout for the attached device.
    def get_channels_layout : ChannelsLayout
      client.get_channels_layout(
        MinknowApi::Device::GetChannelsLayoutRequest.new,
        @ctx
      )
    end

    # Returns the current calibration for the device.
    def get_calibration : CalibrationResponse
      client.get_calibration(
        MinknowApi::Device::GetCalibrationRequest.new,
        @ctx
      )
    end

    # Returns the current temperature reading.
    def get_temperature : Temperature
      client.get_temperature(
        MinknowApi::Device::GetTemperatureRequest.new,
        @ctx
      )
    end

    # Streams device state changes. Returns an iterable server stream.
    def stream_device_state : GRPC::ServerStream(MinknowApi::Device::GetDeviceStateResponse)
      client.stream_device_state(
        MinknowApi::Device::StreamDeviceStateRequest.new,
        @ctx
      )
    end

    # Streams flow cell info changes. Returns an iterable server stream.
    def stream_flow_cell_info : GRPC::ServerStream(MinknowApi::Device::GetFlowCellInfoResponse)
      client.stream_flow_cell_info(
        MinknowApi::Device::StreamFlowCellInfoRequest.new,
        @ctx
      )
    end

    # Streams temperature changes. Returns an iterable server stream.
    def stream_temperature : GRPC::ServerStream(MinknowApi::Device::GetTemperatureResponse)
      client.stream_temperature(
        MinknowApi::Device::StreamTemperatureRequest.new,
        @ctx
      )
    end
  end
end
