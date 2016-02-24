# encoding: utf-8

require 'spec_helper'

describe Tootsie::FfmpegAdapter do
  def temp_file_path(tempfile_args)
    tempfile = Tempfile.new(tempfile_args)
    tempfile.close
    tempfile.path
  end

  def stub_ffprobe_from_file(filename, json_source)
    Ffprober::Parser.stub(:from_file).with(filename) do
      Ffprober::Parser.from_json(File.read(json_source))
    end
  end

  describe "#thumbnail" do
    let(:input_filename) { File.expand_path('../test_files/big_buck_bunny.mp4', File.dirname(__FILE__)) }
    let(:target_filename) { temp_file_path(['tootsie', '.png']) }

    let(:thumbnail_options) do
      {
        width: "480",
        height: "480",
        force_aspect_ratio: true
      }
    end

    let(:expected_command) { "ffmpeg -i '#{input_filename}' -threads '1' -v '99' -y -s '#{thumbnail_options[:width]}x#{thumbnail_options[:height]}' -ss '30.0' -vframes '1' '#{target_filename}'" }

    before(:each) do
      stub_ffprobe_from_file(input_filename, "#{input_filename}.json")
    end

    it "creates a thumbnail" do
      adapter = Tootsie::FfmpegAdapter.new(input_filename)

      expect(Tootsie::CommandRunner).to receive(:new).with(expected_command).and_call_original


      adapter.thumbnail(target_filename, thumbnail_options)
    end
  end
end
