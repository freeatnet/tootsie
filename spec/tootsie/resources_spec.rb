# encoding: utf-8

require 'spec_helper'

include WebMock::API
include Tootsie

describe Resources do

  let! :application do
    Tootsie::Application.configure!(
      :log_path => '/dev/null',
      :queue => {:queue => "test", :adapter => 'null'},
      :aws_access_key_id => "KEY",
      :aws_secret_access_key => "SECRET")
  end

  shared_examples :resource do |resource|
    it 'catches invalid mode' do
      ['x', 'rw', '', nil].each do |mode|
        lambda { resource.open(mode) }.should raise_error(ArgumentError)
      end
    end

    it 'implements basic method interface' do
      [:file, :url, :public_url, :open, :close, :save].each do |method|
        resource.respond_to?(method).should eq true
      end
    end
  end

  describe 'Parser' do
    it 'raises error on unsupported URI' do
      ["ftp://example.com/", "gopher://example.com/"].each do |uri|
        lambda {
          Resources.parse_uri(uri)
        }.should raise_error(Resources::UnsupportedResourceTypeError)
      end
    end

    it 'raises error on unsupported URI' do
      ["xyz", "", nil].each do |uri|
        lambda {
          Resources.parse_uri(uri)
        }.should raise_error(Resources::InvalidUriError)
      end
    end
  end

  describe 'File URIs' do
    include_examples :resource, Resources.parse_uri("file:///tmp")

    it 'has resource interface' do
      file = Tempfile.open("spec")
      file.write("knock knock")
      file.flush

      resource = Resources.parse_uri("file://#{file.path}")
      resource.content_type.should eq nil
      resource.url.should eq "file://#{file.path}"
      resource.public_url.should eq nil

      f = resource.open('r')
      f.read.should eq 'knock knock'
      f.close

      f = resource.open('w')
      f.write("who's there?")
      resource.save

      file.seek(0)
      file.read.should eq "who's there?"
    end

    it 'catches file existence error' do
      path, i = nil, 0
      loop do
        path = "/-/-/-/-/#{Time.now.to_i}#{i}"
        break unless File.exist?(path)
        i += 1
      end
      resource = Resources.parse_uri("file://#{path}")
      lambda {
        resource.open
      }.should raise_error(Resources::ResourceNotFound)
    end
  end

  %w(HTTP HTTPS).each do |protocol|
    let :scheme do
      protocol.downcase
    end

    describe "#{protocol} URIs" do
      include_examples :resource, Resources.parse_uri(
        "#{protocol.downcase}://example.com/")

      it 'has resource interface' do
        stub_request(:get, "#{scheme}://example.com/").
          to_return(
            :status => 200,
            :headers => {'Content-Type' => 'text/plain'},
            :body => 'knock knock')

        resource = Resources.parse_uri("#{scheme}://example.com/")
        resource.content_type.should eq nil
        resource.url.should eq "#{scheme}://example.com/"
        resource.public_url.should eq "#{scheme}://example.com/"

        f = resource.open('r')
        f.read.should eq 'knock knock'
        f.close
        resource.content_type.should eq 'text/plain'

        stub_request(:post, "#{scheme}://example.com/").
          with(
            :content_type => 'text/plain',
            :body => "who's there?").
          to_return(
            :status => 200,
            :body => '')

        f = resource.open('w')
        f.write("who's there?")
        resource.content_type = 'text/plain'
        resource.save
      end
    end
  end

  describe 'S3 URIs' do
    include_examples :resource, Resources.parse_uri("s3:mybucket/foo")

    before do
      stub_request(:head, %r{http://mybucket\.s3\.amazonaws\.com/\??}).
        to_return(:status => 200, :body => '')
    end

    it 'has resource interface' do
      stub_request(:get, %r{http://mybucket\.s3\.amazonaws\.com/foo\??}).
        to_return(
          :status => 200,
          :headers => {'Content-Type' => 'text/plain', 'Content-Length' => '11'},
          :body => 'knock knock')

      put_stub = stub_request(:put, %r{http://mybucket\.s3\.amazonaws\.com/foo\??}).
        with(
          :headers => {'Content-Type' => 'text/plain'},
          :body => "who's there?").
        to_return(:status => 200, :body => '')

      resource = Resources.parse_uri("s3:mybucket/foo")
      resource.content_type.should eq nil
      resource.url.should eq "s3:mybucket/foo"
      resource.public_url.should eq "http://mybucket.s3.amazonaws.com/foo"

      f = resource.open('r')
      f.read.should eq 'knock knock'
      f.close

      f = resource.open('w')
      f.write("who's there?")
      resource.content_type = 'text/plain'
      resource.save

      put_stub.should have_been_requested
    end

    it "uses private ACL, standard storage class by default" do
      put_stub = stub_request(:put, %r{http://mybucket\.s3\.amazonaws\.com/foo\??}).
        with(
          :headers => {
            'Content-Type' => 'text/plain',
            'X-Amz-Acl' => 'private',
            'X-Amz-Storage-Class'=>'STANDARD'
          },
          :body => "who's there?").
        to_return(:status => 200, :body => '')

      resource = Resources.parse_uri("s3:mybucket/foo?acl=private")

      f = resource.open('w')
      f.write("who's there?")
      resource.content_type = 'text/plain'
      resource.save

      put_stub.should have_been_requested
    end

    [nil, 'application/xml'].each do |content_type|
      %w(standard reduced_redundancy).each do |storage_class|
        %w(private public-read authenticated-read).each do |acl|
          it "supports content type #{content_type || 'unspecified'}, storage class #{storage_class}, ACL #{acl}" do
            put_stub = stub_request(:put, %r{http://mybucket\.s3\.amazonaws\.com/foo\??}).
              with(
                :headers => {
                  'Content-Type' => content_type || 'text/plain',
                  'X-Amz-Acl' => acl,
                  'X-Amz-Storage-Class' => storage_class.upcase
                },
                :body => "who's there?").
              to_return(:status => 200, :body => '')

            uri = "s3:mybucket/foo?acl=#{acl}&storage_class=#{storage_class}"
            uri << "&content_type=#{content_type}" if content_type
            resource = Resources.parse_uri(uri)
            resource.url.should eq uri

            f = resource.open('w')
            f.write("who's there?")
            resource.content_type = 'text/plain' unless content_type
            resource.save

            put_stub.should have_been_requested
          end
        end
      end
    end
  end

end