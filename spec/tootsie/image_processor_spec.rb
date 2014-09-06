# encoding: utf-8

require 'spec_helper'

include Tootsie::Processors

describe ImageProcessor do

  describe 'image information' do
    it 'returns basic information from the original image' do
      result, contents = process_image_version('landscape.jpeg', {})
      result[:width].should eq 360
      result[:height].should eq 240
      result[:depth].should eq 8
    end
  end

  describe 'metadata' do
    before do
      expect_any_instance_of(Tootsie::Exiv2MetadataExtractor).to receive(:extract_from_file).
        with(test_file_path('iptc_xmp.jpeg')).exactly(1).times { |_|
        {'Exif.Image.XResolution' => 666}
      }
    end

    it 'returns metadata as part of image processing' do
      result, contents = process_image_version('iptc_xmp.jpeg', {})
      metadata = result[:metadata]
      metadata.should be_a_kind_of(Hash)
      metadata['Exif.Image.XResolution'].should eq 666
    end
  end

  describe 'format conversion' do
    %w(jpeg tiff gif png).each do |format|
      it "converts images to #{format}" do
        result, contents = process_image_version('landscape.jpeg', {:format => format})
        result[:format].should eq format
        extract_dimensions(contents).should eq [360, 240]
      end
    end
  end

  describe 'resizing with scale "down"' do
    let :options do
      {:scale => :down}
    end

    describe 'landscape image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [50, 33]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 33]
      end
    end

    describe 'landscape image, with 270-degree rotation (EXIF orientation 8)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [50, 33]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 33]
      end
    end

    describe 'portrait image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [33, 50]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [33, 50]
      end
    end

    describe 'portrait image, with 90-degree rotation (EXIF orientation 6)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [33, 50]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [33, 50]
      end
    end
  end

  describe 'resizing with scale "fit"' do
    let :options do
      {:scale => :fit}
    end

    describe 'landscape image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [75, 50]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 50]
      end
    end

    describe 'landscape image, with 270-degree rotation (EXIF orientation 8)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [75, 50]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 50]
      end
    end

    describe 'portrait image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [50, 75]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 50]
      end
    end

    describe 'portrait image, with 90-degree rotation (EXIF orientation 6)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [50, 75]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 50]
      end
    end
  end

  describe 'resizing with scale "up"' do
    let :options do
      {:scale => :up}
    end

    describe 'landscape image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 1000, :height => 1000}.merge(options))
        extract_dimensions(contents).should eq [1000, 667]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 1000, :height => 1000, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [1000, 667]
      end
    end

    describe 'landscape image, with 270-degree rotation (EXIF orientation 8)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 1000, :height => 1000}.merge(options))
        extract_dimensions(contents).should eq [1000, 667]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 1000, :height => 1000, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [1000, 667]
      end
    end

    describe 'portrait image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 1000, :height => 1000}.merge(options))
        extract_dimensions(contents).should eq [667, 1000]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 1000, :height => 1000, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [667, 1000]
      end
    end

    describe 'portrait image, with 90-degree rotation (EXIF orientation 6)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 1000, :height => 1000}.merge(options))
        extract_dimensions(contents).should eq [667, 1000]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 1000, :height => 1000, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [667, 1000]
      end
    end
  end

end