module Tootsie
  class Job

    DEFAULT_MAX_RETRIES = 5

    PROGRESS_NOTIFICATION_INTERVAL = 10.seconds

    VALID_TYPES = %w(video audio image).freeze

    class InvalidJobError < StandardError; end

    def initialize(attributes = {})
      attributes = attributes.symbolize_keys
      attributes.assert_valid_keys(
        :uid, :type, :retries, :notification_url, :params, :reference, :path)
      @type = attributes[:type].to_s
      @uid = attributes[:uid]
      @retries_left = attributes[:retries] || DEFAULT_MAX_RETRIES
      @created_at = Time.now
      @notification_url = attributes[:notification_url]
      @params = (attributes[:params] || {}).with_indifferent_access
      @logger = Application.get.logger
      @reference = attributes[:reference]
    rescue ArgumentError => e
      raise InvalidJobError, e.message
    end

    def valid?
      return @type && VALID_TYPES.include?(@type)
    end

    def execute
      @logger.info("Begin processing job: #{attributes.inspect}")
      notify!(:event => :started)
      begin
        result = nil
        elapsed_time = Benchmark.realtime {
          next_notify = Time.now + PROGRESS_NOTIFICATION_INTERVAL
          processor = Processors.const_get("#{@type.camelcase}Processor").new(@params)
          result = processor.execute! { |progress_data|
            if Time.now >= next_notify
              notify!(progress_data.merge(:event => :progress))
              next_notify = Time.now + PROGRESS_NOTIFICATION_INTERVAL
            end
          }
        }
        result ||= {}
        notify!({
          :event => :completed,
          :time_taken => elapsed_time
        }.merge(result))
      rescue Interrupt
        @logger.error "Job interrupted"
        notify!(:event => :failed, :reason => 'Cancelled')
        raise
      rescue => exception
        if @retries_left > 0
          @retries_left -= 1
          temporary_failure(exception)
          @logger.info "Retrying job"
          retry
        else
          permanent_failure(exception)
          notify!(:event => :failed, :reason => exception.message)
        end
      else
        @logger.info "Completed job #{attributes.inspect}"
      end
    end

    # Notify the caller of this job with some message.
    def notify!(message)
      message = message.merge(reference: @reference) if @reference

      notification_url = @notification_url
      if notification_url
        message_json = message.stringify_keys.to_json

        # TODO: Retry on failure
        @logger.info { "Notifying #{notification_url} with message: #{message_json}" }
        begin
          Excon.post(notification_url,
            :body => message_json,
            :headers => {'Content-Type' => 'application/json; charset=utf-8'})
        rescue => exception
          Application.get.report_exception(exception, "Notification failed with exception")
        end
      else
        if (river = Application.get.river)
          begin
            river.publish(message.merge(
              uid: @uid,
              event: "tootsie_#{message[:event]}"))
          rescue => exception
            Application.get.report_exception(exception, "River notification failed with exception")
          end
        end
      end
    end

    def eql?(other)
      attributes == other.attributes
    end

    def ==(other)
      other.is_a?(Job) && eql?(other)
    end

    def attributes
      return {
        :uid => @uid,
        :type => @type,
        :notification_url => @notification_url,
        :retries => @retries_left,
        :reference => @reference,
        :params => @params
      }
    end

    def self.from_json(data)
      new(data)
    end

    def to_json
      attributes.to_json
    end

    attr_accessor :created_at
    attr_accessor :notification_url
    attr_accessor :params
    attr_accessor :type

    attr_reader :uid

    private

      def temporary_failure(exception)
        logger.error "Job failed with exception #{exception.class}: #{exception.message}, will retry"
        notify!(event: :failed_will_retry, reason: exception.message)
        sleep(1)
      end

      def permanent_failure(exception)
        logger.error "No more retries for job, marking as permanently failed"
        case exception
          when Timeout::Error, Excon::Errors::Timeout
            logger.error("The job failed due to timeout")
          when Resources::ResourceError
            logger.error("The job failed due to resource: #{exception}")
          else
            Application.get.report_exception(exception,
              "Job permanently failed with unexpected error")
          end
      end

      def logger
        @logger
      end

  end
end
