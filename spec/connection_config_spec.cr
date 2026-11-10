require "./spec_helper"

describe Minknow::ConnectionConfig do
  it "passes endpoint settings through derived configs to the channel" do
    endpoint = GRPC::EndpointConfig.new(connect_timeout: 2.seconds)
    config = Minknow::ConnectionConfig.new(tls: false, auto_local_auth: false, endpoint_config: endpoint)
    config.with_port(9502).endpoint_config.same?(endpoint).should be_true
    config.local_auth_lookup_config.endpoint_config.same?(endpoint).should be_true
    channel = config.channel
    begin
      channel.endpoint_config.same?(endpoint).should be_true
    ensure
      channel.close
    end
  end

  it "creates independent contexts for short calls and long streams" do
    config = Minknow::ConnectionConfig.new(tls: false, auto_local_auth: false)
    short = config.client_context(deadline: 2.seconds)
    long = config.client_context
    short.deadline.should_not be_nil
    long.deadline.should be_nil
    short.same?(long).should be_false
  end
end
