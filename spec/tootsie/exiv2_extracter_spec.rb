# encoding: utf-8

require 'spec_helper'

if Tootsie::Exiv2MetadataExtractor.available?
  describe Tootsie::Exiv2MetadataExtractor do

    let :extractor do
      Tootsie::Exiv2MetadataExtractor.new
    end

    it 'should read EXIF data' do
      extractor.extract_from_file(test_file_path('iptc.tiff'))
      expect(extractor.metadata['Exif.Image.ImageWidth'][:type]).to eq 'short'
      expect(extractor.metadata['Exif.Image.ImageWidth'][:value]).to eq 10
      expect(extractor.metadata['Exif.Image.ImageLength'][:type]).to eq 'short'
      expect(extractor.metadata['Exif.Image.ImageLength'][:value]).to eq 10
      expect(extractor.metadata['Exif.Image.ImageDescription'][:type]).to eq 'ascii'
      expect(extractor.metadata['Exif.Image.ImageDescription'][:value]).to eq 'Tømmer på vannet ved Krøderen'
    end

    it 'should read IPTC data' do
      extractor.extract_from_file(test_file_path('iptc.tiff'))
      expect(extractor.metadata['Iptc.Application2.City'][:type]).to eq 'string'
      expect(extractor.metadata['Iptc.Application2.City'][:value]).to eq 'Krødsherad'
      expect(extractor.metadata['Iptc.Application2.ObjectName'][:type]).to eq 'string'
      expect(extractor.metadata['Iptc.Application2.ObjectName'][:value]).to eq 'Parti fra Krødsherad'
    end

    it 'should read XMP data' do
      extractor.extract_from_file(test_file_path('iptc.tiff'))
      expect(extractor.metadata['Xmp.dc.description'][:type]).to eq 'lang_alt'
      expect(extractor.metadata['Xmp.dc.description'][:value]).to eq 'lang="x-default" Tømmer på vannet ved Krøderen'
      expect(extractor.metadata['Xmp.tiff.YResolution'][:type]).to eq 'xmp_text'
      expect(extractor.metadata['Xmp.tiff.YResolution'][:value]).to eq '300'
    end

  end
else
  warn "'exiv2' tool not available, tests skipped."
end
