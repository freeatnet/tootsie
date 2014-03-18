require 'sinatra/base'

module Tootsie
  module API
    class V1 < Sinatra::Base

      configure do |config|
        config.set :sessions, false
        config.set :run, false
        config.set :logging, true
        config.set :show_exceptions, false
      end

      register Sinatra::Pebblebed

      not_found do
        halt 404, "Not found"
      end

      post %r{/job(s)?/?} do
        job_data = JSON.parse(request.env["rack.input"].read).
          symbolize_keys.except(:session, :captures, :splat)

        logger.info "Handling job: #{job_data.inspect}"

        path = job_data.delete(:path)
        path ||= 'tootsie'  # Technically not a valid path, though

        job_data[:uid] = "tootsie_job:#{path}$" + Time.now.strftime('%Y%m%d%H%M%S') +
          SecureRandom.random_number(2 ** 64).to_s(36)

        job = Job.new(job_data)
        unless job.valid?
          halt 400, 'Invalid job specification'
        end
        Application.get.queue.push(job)

        halt 201, job.uid
      end

      get '/status' do
        out = {}
        if (count = Application.get.queue.count)
          out['queue_count'] = count
        end
        out.to_json
      end

      private

        def logger
          return @logger ||= Application.get.logger
        end

    end
  end
end