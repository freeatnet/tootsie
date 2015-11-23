# encoding: utf-8

require 'spec_helper'

describe Tootsie::S3Utilities do

  it 'parses URIs with bucket and path' do
    out = Tootsie::S3Utilities.parse_uri("s3:mybucket/some/path")
    expect(out[:bucket]).to eq 'mybucket'
    expect(out[:key]).to eq 'some/path'
    expect(out.length).to eq 2
  end

  it 'parses URIs and returns indifferent hash' do
    out = Tootsie::S3Utilities.parse_uri("s3:mybucket/some/path")
    expect(out[:bucket]).to eq out['bucket']
  end

  it 'parses URIs with bucket and path and one key' do
    out = Tootsie::S3Utilities.parse_uri("s3:mybucket/some/path?a=1")
    expect(out[:bucket]).to eq 'mybucket'
    expect(out[:key]).to eq 'some/path'
    expect(out[:a].to_s).to eq '1'
    expect(out.length).to eq 3
  end

  it 'parses URIs with bucket and path and multiple keys' do
    out = Tootsie::S3Utilities.parse_uri("s3:mybucket/some/path?a=1&b=2")
    expect(out[:bucket]).to eq 'mybucket'
    expect(out[:key]).to eq 'some/path'
    expect(out[:a].to_s).to eq '1'
    expect(out[:b].to_s).to eq '2'
    expect(out.length).to eq 4
  end

  it 'throws exceptions on non-S3 URIs' do
    expect(lambda { Tootsie::S3Utilities.parse_uri('http://example.com/') }).to raise_error
  end

end
