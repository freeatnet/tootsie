# encoding: utf-8

require 'spec_helper'
require 'ostruct'

FakeEvent = Class.new(OpenStruct)

describe Tootsie::Worker do

  subject do
    Tootsie::Worker.new
  end

  let :invalid_job do
    FakeEvent.new(payload: {uid: 'bing', status: 'sad'})
  end

  it 'ignores invalid jobs' do
    expect(-> {
      expect(subject.call(invalid_job)).to be_nil
    }).not_to raise_error
  end

end
