# encoding: utf-8

require 'spec_helper'

include Tootsie
include Tootsie::Processors

describe VideoProcessor do

  describe "#execute!" do
    let(:input_url) { "http://example.com/video.mp4" }
    let(:input_data) { "garblegarblegarble" + rand(0..1000).to_s }
    let(:output_url) { "http://example.com/video.flv" }
    let(:output_data) { "DATA" + rand(0..1000).to_s }

    subject { VideoProcessor.new(processor_params) }

    before(:each) do
      stub_request(:get, input_url).
        to_return(:status => 200, :body => input_data)
    end

    context "with video transcoding requested" do
      let (:version_options) do
        {
          :target_url => output_url,
          :audio_sample_rate => 44100,
          :audio_bitrate => 64000,
          :format => 'flv',
          :width => 600,
          :height => 400,
          :quality => 1.0,
          :content_type => "video/x-flv"
        }
      end

      let!(:post_stub) do
        stub_request(:post, output_url).with(
          :headers => {'Content-Type' => version_options[:content_type]},
          :body => output_data
        ).to_return(:status => 200)
      end

      before(:each) do
        expect_any_instance_of(FfmpegAdapter).to receive(:transcode).
          with(kind_of(String), kind_of(String), kind_of(Hash)).
          once { |_, in_path, out_path, adapter_options|
          expect(adapter_options).to include(version_options.except(:target_url))
          File.open(out_path, "w") { |f|
            f.write(output_data)
          }
        }
      end

      context "versions as a hash" do
        let(:processor_params) do
          {
            :input_url => input_url,
            :versions => version_options
          }
        end

        it "performs basic transcoding" do
          subject.execute!
          expect(post_stub).to have_been_requested
        end
      end

      context "versions as an array" do
        let(:processor_params) do
          {
            :input_url => input_url,
            :versions => [version_options, ]
          }
        end

        it "performs basic transcoding" do
          subject.execute!
          expect(post_stub).to have_been_requested
        end
      end
    end

    context "with video transcoding and a thumbnail requested" do
      let(:thumbnail_target_url) { "http://example.com/video.jpg" }
      let(:thumbnail_options) do
        {
          :target_url => thumbnail_target_url,
          :width => 600,
          :height => 400
        }
      end
      let(:version_options) do
        {
          :target_url => output_url,
          :audio_sample_rate => 44100,
          :audio_bitrate => 64000,
          :format => 'flv',
          :width => 600,
          :height => 400,
          :quality => 1.0,
          :content_type => "video/x-flv"
        }
      end

      let!(:version_post_stub) do
        stub_request(:post, output_url).with(
          :headers => {'Content-Type' => version_options[:content_type]},
          :body => output_data
        ).to_return(:status => 200)
      end

      let!(:thumbnail_post_stub) do
        # TODO: Verify headers and data for the thumbnail
        stub_request(:post, thumbnail_target_url).
          to_return(:status => 200)
      end

      before(:each) do
        expect_any_instance_of(FfmpegAdapter).to receive(:transcode).
          with(kind_of(String), kind_of(String), kind_of(Hash)).
          once { |_, in_path, out_path, adapter_options|
          expect(adapter_options).to include(version_options.except(:target_url))
          File.open(out_path, "w") { |f|
            f.write(output_data)
          }
        }
      end

      let(:processor_params) do
        {
          :input_url => input_url,
          :thumbnail => thumbnail_options,
          :versions => [ version_options, ]
        }
      end

      it "performs basic transcoding and creates a thumbnail" do
        subject.execute!
        expect(version_post_stub).to have_been_requested
        expect(thumbnail_post_stub).to have_been_requested
      end
    end
  end
end
