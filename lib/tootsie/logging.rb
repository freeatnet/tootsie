require 'logger'

module Tootsie

  def self.logger
    @logger ||= Configuration.instance.logger
  end

  class PrefixedLogger < Logger
    def initialize(logger, prefix)
      @logger = logger
      @level = logger.level
      @prefix = prefix
    end

    def add(severity, message = nil, progname = nil, &block)
      return if severity < @level
      message ||= block.call if block
      if not message and progname
        message = progname
        progname = nil
      end
      if message
        message = "#{@prefix}: #{message}"
      end
      @logger.add(severity, message, progname)
    end
  end

  module PrefixedLogging

    def logger
      @logger ||= PrefixedLogger.new(Tootsie.logger, logger_prefix)
    end

    protected

      def logger_prefix
        self.class.name.split('::').reject { |s| s == 'Tootsie' }.join('/')
      end

  end

end
