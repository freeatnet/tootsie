module Tootsie

  class CommandExecutionFailed < StandardError
    def initialize(message, output)
      super("#{message}\n#{output}")
      @output = output
    end
    attr_reader :output
  end

  class CommandRunner

    include PrefixedLogging

    def initialize(command_line, options = {})
      @options = options.symbolize_keys
      @options.assert_valid_keys(:ignore_exit_code, :output_encoding)
      @command_line = command_line
      @command = command_line.split.first
    end

    def run(params = {}, &block)
      command_line = @command_line
      if params.any?
        params = params.with_indifferent_access
        command_line = command_line.gsub(/(^|\s):(\w+)/) do
          pre, key, all = $1, $2, $~[0]
          if params.include?(key)
            value = params[key]
            value = "'#{value}'" if value =~ /\s/
            "#{pre}#{value}"
          else
            all
          end
        end
      end
      command_line = "#{command_line} 2>&1"

      logger.info("Running: #{command_line}") if logger.info?

      buffered_output, buffer_exceeded = '', false

      elapsed_time = Benchmark.realtime {
        IO.popen(command_line, "r:#{@options[:output_encoding] || 'utf-8'}") do |output|
          output.each_line do |line|
            if buffered_output.length < 10240
              buffered_output << line
            elsif not buffer_exceeded
              buffer_exceeded = true
              buffered_output << '[...]'
            end

            line.split(/\r/).each do |linepart|
              logger.info("--> #{linepart.strip}") if logger.info?
              yield linepart if block_given?
            end
          end
        end
      }

      error, success, status = nil, false, $?
      if status.exited?
        if status.exitstatus != 0
          if @options[:ignore_exit_code]
            # Ignore
          else
            error = "Command failed with exit code #{status.exitstatus}"
          end
        else
          success = true
          logger.info "Finished in #{elapsed_time.round(3)} secs"
        end
      elsif status.stopped?
        error = "Command stopped unexpectedly with signal #{status.stopsig}"
      elsif status.signaled?
        error = "Command died unexpectedly by signal #{status.termsig}"
      else
        error = "Command died unexpectedly"
      end
      if error
        raise CommandExecutionFailed.new("#{error}: #{command_line}",
          buffered_output)
      end
      return success
    end

    protected

      def logger_prefix
        "#{super} (#{@command})"
      end

  end
end
