# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require "tootsie/version"

Gem::Specification.new do |s|
  s.name        = "tootsie"
  s.version     = Tootsie::VERSION
  s.authors     = ["Alexander Staubo"]
  s.email       = ["alex@bengler.no"]
  s.homepage    = "http://github.com/bengler/tootsie"
  s.summary     = s.description = %{Tootsie is a simple audio/video/image transcoding/modification application.}

  s.rubyforge_project = "tootsie"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'json', ['~> 1.7']
  s.add_runtime_dependency 'sinatra', ['~> 1.2']
  s.add_runtime_dependency 'activesupport', ['~> 3.2.0']
  s.add_runtime_dependency 'excon', ['~> 0.19']
  s.add_runtime_dependency 'builder', ['~> 2.1']
  s.add_runtime_dependency 'mime-types', ['~> 1.16']
  s.add_runtime_dependency 'xml-simple', ['~> 1.0']
  s.add_runtime_dependency 's3', ['= 0.3.8']  # Later versions are broken
  s.add_runtime_dependency 'bunny', ['~> 0.8.0']
  s.add_runtime_dependency 'sqs', ['~> 0.1']
  s.add_runtime_dependency 'unicorn', ['~> 4.1']
  s.add_runtime_dependency 'i18n', ['>= 0.4']
  s.add_runtime_dependency 'scashin133-syslog_logger', ['~> 1.7']
  s.add_runtime_dependency 'airbrake', '~> 3.1'
  s.add_runtime_dependency 'pebblebed', '~> 0.0.42'
  s.add_runtime_dependency 'nokogiri', '~> 1.6.1'

  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "webmock", ">= 1.11"
end
