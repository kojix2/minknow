require "./spec_helper"

# A local protocol fixture. No MinKNOW process or sequencing hardware is used.
private class LiveReadsPeer < GRPC::Service
  getter requests = [] of Minknow::DataService::LiveRequest

  def initialize(@terminal : GRPC::Status = GRPC::Status.ok)
  end

  def service_full_name : String
    "minknow_api.data.DataService"
  end

  def dispatch(method : String, request_body : Bytes, ctx : GRPC::ServerContext) : {Bytes, GRPC::Status}
    {Bytes.empty, GRPC::Status.unimplemented}
  end

  def bidi_streaming?(method : String) : Bool
    method == "get_live_reads"
  end

  def dispatch_bidi_stream(method : String, requests : GRPC::RawRequestStream,
                           ctx : GRPC::ServerContext, writer : GRPC::RawResponseStream) : GRPC::Status
    requests.each do |bytes|
      request = Minknow::DataService::LiveRequest.decode(bytes)
      @requests << request
      response = Minknow::DataService::LiveResponse.new
      if request.setup
        read = Minknow::DataService::ReadData.new
        read.id = "local-read"
        read.chunk_start_sample = 4096_u64
        read.chunk_length = 65536_u64
        read.raw_data = Bytes.new(128 * 1024) { |i| (i % 251).to_u8 }
        response.channels[3_u32] = read
      elsif actions = request.actions
        actions.actions.each do |action|
          reply = Minknow::DataService::ActionResponse.new
          reply.action_id = action.action_id
          response.action_responses << reply
        end
      end
      writer.send_raw(response.encode)
      return @terminal if request.actions
    end
    @terminal
  end
end

private def with_live_reads_peer(terminal : GRPC::Status = GRPC::Status.ok, &)
  listener = TCPServer.new("127.0.0.1", 0)
  port = listener.local_address.port
  listener.close
  server = GRPC::Server.new
  peer = LiveReadsPeer.new(terminal)
  server.handle(peer)
  server.bind("127.0.0.1:#{port}")
  server.start
  channel = GRPC::Channel.new("http://127.0.0.1:#{port}")
  service = Minknow::DataService.new(channel, GRPC::ClientContext.new(deadline: 5.seconds))
  begin
    yield service, peer
  ensure
    channel.close
    server.stop
  end
end

describe "MinKNOW live reads over local HTTP/2" do
  {GRPC::Status.ok, GRPC::Status.unavailable("acquisition stopped")}.each do |terminal|
    it "interleaves real setup, signal bytes and actions before server completion #{terminal.code}" do
      with_live_reads_peer(terminal) do |service, peer|
        call = service.live_reads
        replies = Channel(Minknow::DataService::LiveResponse).new
        done = Channel(Exception?).new(1)
        spawn do
          call.each { |reply| replies.send(reply) }
          done.send(nil)
        rescue ex
          done.send(ex)
        end
        begin
          call.send(Minknow::DataService.setup_request(first_channel: 3, last_channel: 3))
          select
          when response = replies.receive
            read = response.channels[3_u32]
            read.id.should eq("local-read")
            read.chunk_start_sample.should eq(4096_u64)
            read.chunk_length.should eq(65536_u64)
            read.raw_data.should eq(Bytes.new(128 * 1024) { |i| (i % 251).to_u8 })
          when timeout(5.seconds)
            fail "live-read data required closing the request direction"
          end
          action = Minknow::DataService.stop_action("stop-local", 3_u32, "local-read")
          call.send(Minknow::DataService.actions_request([action]))
          select
          when response = replies.receive
            response.action_responses.map(&.action_id).should eq(["stop-local"])
          when timeout(5.seconds)
            fail "action acknowledgement required closing the request direction"
          end
          select
          when error = done.receive
            raise error if error
          when timeout(5.seconds)
            fail "server completion did not finish the response iterator"
          end
          call.final_status.should eq(terminal)
          peer.requests.size.should eq(2)
          setup = peer.requests.first.setup.should_not(be_nil)
          setup.first_channel.should eq(3_u32)
          actions = peer.requests.last.actions.should_not(be_nil)
          actions.actions.first.id.should eq("local-read")
          expect_raises(GRPC::SendClosedError) { call.send(Minknow::DataService.setup_request) }
        ensure
          replies.close
          call.cancel
        end
      end
    end
  end

  it "cancels an idle live-read call and opens another call on the same channel" do
    with_live_reads_peer do |service, _peer|
      cancelled = service.live_reads
      cancelled.cancel
      cancelled.final_status.try(&.code).should eq(GRPC::StatusCode::CANCELLED)
      call = service.live_reads
      call.send(Minknow::DataService.actions_request([Minknow::DataService.stop_action("stop", 3_u32, "local-read")]))
      call.map(&.action_responses.map(&.action_id)).should eq([["stop"]])
      call.final_status.should eq(GRPC::Status.ok)
    end
  end
end
