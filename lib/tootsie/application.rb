module Tootsie

  class Application

    def initialize
      @@instance = self
      @logger = Logger.new('/dev/null')
      @configuration = Configuration.new
    end

    def configure!(config_path_or_hash)
      if config_path_or_hash.respond_to?(:to_str)
        @configuration.load_from_file(config_path_or_hash)
      else
        @configuration.update!(config_path_or_hash)
      end

      if defined?(LOGGER)
        @logger = LOGGER  # Can be set externally to default to a global logger
        if @configuration.log_path
          @logger.warn "Logger overridden, ignoring configuration log path"
        end
      else
        case @configuration.log_path
          when 'syslog'
            @logger = SyslogLogger.new('tootsie')
          when String
            @logger = Logger.new(@configuration.log_path)
          else
            @logger = Logger.new($stderr)
        end
      end

      @logger.info "Starting"

      queue_options = @configuration.queue_options ||= {}

      @queue = Tootsie::Queue.new(
        :host_name => queue_options[:host],
        :queue_name => queue_options[:queue],
        :max_backoff => queue_options[:max_backoff])

      @river = Pebblebed::River.new
    end

    def process_jobs
      loop do
        @queue.consume do |message|
          Job.from_json(message).execute
        end
      end
    end

    def s3_service
      abort "AWS access key and secret required" unless
        @configuration.aws_access_key_id and @configuration.aws_secret_access_key
      return @s3_service ||= ::S3::Service.new(
        :access_key_id => @configuration.aws_access_key_id,
        :secret_access_key => @configuration.aws_secret_access_key)
    end

    # Report an exception.
    def report_exception(message = nil, &block)
      if @logger.respond_to?(:exception)
        # This allows us to plug in custom exception handling
        logger.error(message) if message
        @logger.exception(exception)
      else
        @logger.error("#{message}: #{exception.class}: #{exception}")
      end
    end

    class << self
      def get
        @@instance ||= Application.new
      end

      def configure!(config_path_or_hash)
        app = get
        app.configure!(config_path_or_hash)
        app
      end
    end

    attr_reader :configuration
    attr_reader :queue
    attr_reader :logger
    attr_reader :river

  end

end
