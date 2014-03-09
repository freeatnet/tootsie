# Create site.rb in production in order to do overrides of things like logging
load(File.expand_path('../site.rb', __FILE__)) if File.exist?(File.expand_path('../site.rb', __FILE__))

environment = ENV['RACK_ENV'] ||= 'development'

require 'rubygems'
require 'bundler'
Bundler.require(:default, environment.to_sym)

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'tootsie'

config_paths = [
  ENV['TOOTSIE_CONFIG'],
  File.expand_path("../../config/tootsie.conf", __FILE__),
  '/etc/tootsie/tootsie.conf'
].compact

if (path = config_paths.select(&File.method(:exist?)).first)
  Tootsie::Application.configure!(path)
end
