require File.expand_path('../config/environment', __FILE__)
require File.expand_path('../api/v1', __FILE__)

map '/api/tootsie/v1' do
  run Tootsie::API::V1
end
