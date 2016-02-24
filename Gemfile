source 'https://rubygems.org/'

gem 'json', '~> 1.7'
gem 'sinatra', '~> 1.2'
gem 'activesupport', '~> 4.0'
gem 'excon', '~> 0.45'
gem 'builder', '~> 2.1'
gem 'mime-types', '~> 1.16'
gem 'xml-simple', '~> 1.0'
gem 's3', '= 0.3.8'  # Later versions are broken
gem 'unicorn', '~> 4.8.3'
gem 'i18n', '>= 0.4'
gem 'scashin133-syslog_logger', '~> 1.7'
gem 'nokogiri', '~> 1.6.1'
gem 'pebblebed', '~> 0.3.0'
gem 'pebbles-river', '~> 0.2.0'

# Media support
gem 'ffprober', '~> 0.5.1'

group :production do
  gem 'airbrake', '~> 3.1'
end

group :test do
  gem "rspec"
  gem "simplecov"
  gem "rack-test"
  gem "webmock", ">= 1.11"
end
