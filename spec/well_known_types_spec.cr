require "./spec_helper"
require "../src/generated/google/protobuf/wrappers.pb"
require "../src/generated/google/protobuf/any.pb"
require "../src/generated/google/protobuf/duration.pb"
require "../src/generated/google/protobuf/timestamp.pb"
require "../src/generated/google/protobuf/empty.pb"
require "../src/generated/google/protobuf/descriptor.pb"

describe "generated Google protobuf types" do
  it "omits positive zero in FloatValue and DoubleValue without Float extensions" do
    Google::Protobuf::FloatValue.new.encode.should be_empty
    Google::Protobuf::DoubleValue.new.encode.should be_empty
  end

  it "preserves negative zero in FloatValue and DoubleValue" do
    float = Google::Protobuf::FloatValue.new
    float.value = -0.0_f32
    float.encode.should eq(Bytes[0x0d, 0, 0, 0, 0x80])
    Google::Protobuf::FloatValue.decode(float.encode).value.sign_bit.should eq(-1)

    double = Google::Protobuf::DoubleValue.new
    double.value = -0.0_f64
    double.encode.should eq(Bytes[0x09, 0, 0, 0, 0, 0, 0, 0, 0x80])
    Google::Protobuf::DoubleValue.decode(double.encode).value.sign_bit.should eq(-1)
  end

  it "round-trips finite values, infinities and NaN in both floating wrappers" do
    [1.25_f32, -2.5_f32, Float32::INFINITY, -Float32::INFINITY, Float32::NAN].each do |value|
      float = Google::Protobuf::FloatValue.new
      float.value = value
      double = Google::Protobuf::DoubleValue.new
      double.value = value.to_f64
      decoded_float = Google::Protobuf::FloatValue.decode(float.encode)
      decoded_double = Google::Protobuf::DoubleValue.decode(double.encode)
      if value.nan?
        decoded_float.value.nan?.should be_true
        decoded_double.value.nan?.should be_true
      else
        decoded_float.value.should eq(value)
        decoded_double.value.should eq(value.to_f64)
      end
    end
  end

  it "preserves unknown wrapper fields and includes them in equality" do
    encoded = Bytes[0x10, 0x07]
    float = Google::Protobuf::FloatValue.decode(encoded)
    float.encode.should eq(encoded)
    float.should_not eq(Google::Protobuf::FloatValue.new)
    double = Google::Protobuf::DoubleValue.decode(encoded)
    double.encode.should eq(encoded)
    double.should_not eq(Google::Protobuf::DoubleValue.new)
  end

  it "rejects mismatched wire types in floating wrappers" do
    expect_raises(Proto::DecodeError, "wire type mismatch") do
      Google::Protobuf::FloatValue.decode(Bytes[0x09, 0, 0, 0, 0, 0, 0, 0, 0])
    end
    expect_raises(Proto::DecodeError, "wire type mismatch") do
      Google::Protobuf::DoubleValue.decode(Bytes[0x0d, 0, 0, 0, 0])
    end
  end

  it "round-trips Any payloads and unknown fields" do
    message = Google::Protobuf::Any.new
    message.type_url = "type.example/Message"
    message.value = Bytes[1, 2, 3]
    encoded = message.encode + Bytes[0x18, 0x07]
    decoded = Google::Protobuf::Any.decode(encoded)
    decoded.type_url.should eq(message.type_url)
    decoded.value.should eq(message.value)
    decoded.unknown_fields.size.should eq(1)
    decoded.encode.should eq(encoded)
  end

  it "round-trips Duration and Timestamp values" do
    duration = Google::Protobuf::Duration.new
    duration.seconds = -2_i64
    duration.nanos = -500
    Google::Protobuf::Duration.decode(duration.encode).should eq(duration)

    timestamp = Google::Protobuf::Timestamp.new
    timestamp.seconds = 1_700_000_000_i64
    timestamp.nanos = 123_456_789
    Google::Protobuf::Timestamp.decode(timestamp.encode).should eq(timestamp)
  end

  it "preserves unknown fields in Empty" do
    encoded = Bytes[0x08, 0x07]
    Google::Protobuf::Empty.decode(encoded).encode.should eq(encoded)
  end

  it "provides usable descriptor messages" do
    descriptor = Google::Protobuf::FileDescriptorProto.new
    descriptor.name = "example.proto"
    descriptor.syntax = "proto3"
    descriptors = Google::Protobuf::FileDescriptorSet.new
    descriptors.file << descriptor
    decoded = Google::Protobuf::FileDescriptorSet.decode(descriptors.encode)
    decoded.file.first.name.should eq("example.proto")
    decoded.file.first.syntax.should eq("proto3")
  end
end
