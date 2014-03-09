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

      adapter = (queue_options[:adapter] || 'sqs').to_s
      case adapter
        when 'sqs'
          @queue = Tootsie::SqsQueue.new(
            :queue_name => queue_options[:queue],
            :access_key_id => @configuration.aws_access_key_id,
            :secret_access_key => @configuration.aws_secret_access_key,
            :max_backoff => queue_options[:max_backoff])
        when 'amqp'
          @queue = Tootsie::AmqpQueue.new(
            :host_name => queue_options[:host],
            :queue_name => queue_options[:queue],
            :max_backoff => queue_options[:max_backoff])
        when 'file'
          @queue = Tootsie::FileSystemQueue.new(queue_options[:root])
        when 'null'
          @queue = Tootsie::NullQueue.new
        else
          raise 'Invalid queue configuration'
      end

      @task_manager = TaskManager.new(@queue)
    end

    def s3_service
      abort "AWS access key and secret required" unless
        @configuration.aws_access_key_id and @configuration.aws_secret_access_key
      return @s3_service ||= ::S3::Service.new(
        :access_key_id => @configuration.aws_access_key_id,
        :secret_access_key => @configuration.aws_secret_access_key)
    end

    # Handle exceptions in a block. Will log as appropriate.
    def handle_exceptions(&block)
      begin
        yield
      rescue => exception
        if @logger.respond_to?(:exception)
          # This allows us to plug in custom exception handling
          @logger.exception(exception)
        else
          @logger.error("Exception caught: #{exception.class}: #{exception}")
        end
      end
      nil
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
    attr_reader :task_manager
    attr_reader :queue
    attr_reader :logger

  end

end
