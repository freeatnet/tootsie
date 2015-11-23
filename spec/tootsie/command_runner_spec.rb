# encoding: utf-8

require 'spec_helper'

describe Tootsie::CommandRunner do

  it 'run simple commands' do
    expect(Tootsie::CommandRunner.new('ls').run).to be_truthy
  end

  it 'replace arguments in command lines' do
    lines = []
    Tootsie::CommandRunner.new('echo :text').run(:text => "test") do |line|
      lines << line.strip
    end
    expect(lines).to eq ["test"]
  end

  it 'throw exceptions on failure' do
    expect(lambda { Tootsie::CommandRunner.new('exit 1').run }).to raise_error(
      Tootsie::CommandExecutionFailed)
  end

  it 'not throw exceptions on failure with option' do
    expect(lambda { Tootsie::CommandRunner.new('exit 1', :ignore_exit_code => true).run }).to_not raise_error
    expect(Tootsie::CommandRunner.new('exit 1', :ignore_exit_code => true).run).to eq false
  end

end
