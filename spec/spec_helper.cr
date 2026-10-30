require "spec"
require "file/tempfile"
require "../src/minknow"

class RecordingChannel < GRPC::Channel
  getter calls = [] of Tuple(String, String, Bytes, GRPC::ClientContext)
  getter responses = {} of String => Bytes
  getter sent_requests = [] of Bytes

  def initialize
    super("http://localhost:9501")
  end

  def unary_call(
    service : String,
    method : String,
    request_bytes : Bytes,
    ctx : GRPC::ClientContext = GRPC::ClientContext.new,
  ) : GRPC::ResponseEnvelope
    @calls << {service, method, request_bytes, ctx}
    GRPC::ResponseEnvelope.new(
      GRPC::CallInfo.new("/#{service}/#{method}", GRPC::RPCKind::Unary),
      responses.fetch(method, Bytes.empty),
      GRPC::Status.ok
    )
  end

  def open_server_stream(
    service : String,
    method : String,
    request_bytes : Bytes,
    ctx : GRPC::ClientContext = GRPC::ClientContext.new,
  ) : GRPC::RawServerStream
    @calls << {service, method, request_bytes, ctx}
    messages = ::Channel(Bytes?).new(1)
    messages.send(responses.fetch(method, Bytes.empty))
    messages.close
    GRPC::RawServerStream.new(messages, -> { GRPC::Status.ok })
  end

  def open_bidi_stream_live(
    service : String,
    method : String,
    ctx : GRPC::ClientContext = GRPC::ClientContext.new,
    send_queue_size : Int32 = 0,
  ) : GRPC::RawBidiCall
    @calls << {service, method, Bytes.empty, ctx}
    messages = ::Channel(Bytes?).new(1)
    messages.send(responses.fetch(method, Bytes.empty))
    messages.close
    GRPC::RawBidiCall.new(
      ->(request : Bytes) { @sent_requests << request; nil },
      -> { },
      messages,
      -> { GRPC::Metadata.new },
      -> { GRPC::Status.ok },
      -> { GRPC::Metadata.new },
      -> { }
    )
  end
end

class TokenFileConfig < Minknow::ConnectionConfig
  property token_path : String? = nil

  private def local_auth_token_path : String?
    @token_path
  end
end

class RecordingManager < Minknow::Manager
  property recording_channel : GRPC::Channel? = nil

  def channel : GRPC::Channel
    recording_channel || super
  end
end
