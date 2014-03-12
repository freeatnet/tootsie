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
        attributes = {
          type: 'image',
          notification_url: "http://example.com/transcoder_notification",
          reference: {'meaning' => 42},
          params: {}
        }

        queue.stub(:push) { nil }
        expect(queue).to receive(:push) do |j|
          j.class.should eq Tootsie::Job
          j.attributes.except(:uid, :retries).should eq attributes
          j.attributes[:uid].should =~ /^tootsie_job:dustin_hoffman(\.|\$)/
          j.attributes.should include(:retries)
        end
        post '/jobs', JSON.dump(attributes.merge(
          path: 'dustin_hoffman'
        ))
        last_response.status.should eq 201
      end

      it 'accepts job without a path' do
        attributes = {
          type: 'image',
          notification_url: "http://example.com/transcoder_notification",
          reference: {'meaning' => 42},
          params: {}
        }

        queue.stub(:push) { nil }
        expect(queue).to receive(:push) do |j|
          j.attributes[:uid].should =~ /^tootsie_job:tootsie(\.|\$)/
        end
        post '/jobs', JSON.dump(attributes)
        last_response.status.should eq 201
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