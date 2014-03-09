require 'spec_helper'

include WebMock::API
include Tootsie::API

describe V1 do

  include Rack::Test::Methods

  def app
    V1
  end

  let! :application do
    app = Tootsie::Application.get
    app.configure!(
      log_path: '/dev/null',
      queue: {queue: "test"},
      aws_access_key_id: "KEY",
      aws_secret_access_key: "SECRET")
    app
  end

  let :queue do
    application.queue
  end

  ["/jobs", "/job"].each do |path|
    describe "POST #{path}" do

      it 'posts job on queue' do
        queue.stub(:push) { nil }

        attributes = {
          type: 'image',
          notification_url: "http://example.com/transcoder_notification",
          reference: {'meaning' => 42},
          params: {}
        }

        post '/jobs', JSON.dump(attributes)
        last_response.status.should eq 201

        expect(queue).to have_received(:push).with(Job.new(attributes))
      end

    end
  end

  describe "GET /status" do

    it 'returns a status hash with queue length' do
      queue.stub(:count) { 42 }

      get '/status'
      last_response.status.should eq 200
      JSON.parse(last_response.body).should eq({"queue_count" => 42})
    end

  end

end