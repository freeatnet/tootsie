module Tootsie

  # Runs the daemon from the command line.
  class Runner

    def initialize
      @run_as_daemon = false
      @config_path = '/etc/tootsie/tootsie.conf'
      @app = Application.new
    end

    def run!(arguments = [])
      # Backwards compatibility
      command = arguments.shift if %w(start stop).include?(arguments[0])

      OptionParser.new do |opts|
        opts.banner = %{\
Usage: #{File.basename($0)} [OPTIONS] start
       #{File.basename($0)} [OPTIONS] stop
}
        opts.separator ""
        opts.on("-d", "--daemon", 'Run as daemon') do
          @run_as_daemon = true
        end
        opts.on("-p PATH", "--pidfile", "Store pid in PATH (defaults to #{@pidfile})") do |value|
          @pidfile = File.expand_path(value)
        end
        opts.on("-c FILE", "--config FILE", "Read configuration from FILE (defaults to #{@config_path})") do |value|
          @config_path = File.expand_path(value)
        end
        opts.on("-h", "--help", "Show this help.") do
          puts opts
          exit
        end
        opts.order!(arguments) { |v| opts.terminate(v) }
      end

      command ||= arguments.shift
      unless command
        abort "Run with #{$0} -h for help."
      end
      case command
        when 'start'
          @app.configure!(@config_path)
          if @run_as_daemon
            daemonize!
          else
            execute!
          end
        when 'stop'
          @app.configure!(@config_path)
          stop!
        else
          abort "Don't know command #{command}."
      end
    end

    private

      def stop!
        stopped = false
        begin
          pid = File.read(pid_path).to_i
        rescue Errno::ENOENT
          pid = nil
        end
        if pid and pid != 0
          begin
            Process.kill('TERM', pid)
          rescue Errno::ESRCH
          else
            begin
              timeout(30) do
                loop do
                  begin
                    Process.kill(0, pid)
                  rescue Errno::ESRCH
                    stopped = true
                    break
                  else
                    sleep(1)
                  end
                end
              end
            rescue Timeout::Error
              abort "Daemon did not stop in time."
            end
          end
        end
        unless stopped
          puts "Daemon is not running."
        end
      end

      def execute!
        with_pid do
          @spawner = Spawner.new(
            :num_children => @app.configuration.worker_count,
            :logger => logger)
          @spawner.on_spawn do
            $0 = "tootsie: worker"
            Signal.trap('TERM') do
              exit(2)
            end
            with_lifecycle_logging("Worker [#{Process.pid}]") do
              @app.process_jobs
            end
          end
          with_lifecycle_logging('Main process') do
            @spawner.run
          end
          @spawner.terminate
        end
      end

      def daemonize!(&block)
        return Process.fork {
          logger = @app.logger

          Process.setsid
          0.upto(255) do |n|
            File.for_fd(n, "r").close rescue nil
          end

          File.umask(27)
          Dir.chdir('/')
          $stdin.reopen("/dev/null", 'r')
          $stdout.reopen("/dev/null", 'w')
          $stderr.reopen("/dev/null", 'w')

          Signal.trap("HUP") do
            logger.debug("Ignoring SIGHUP")
          end

          execute!
        }
      end

      def with_pid(&block)
        path = pid_path
        File.open(path, 'w') do |file|
          file << Process.pid
        end
        begin
          yield
        ensure
          File.delete(path) rescue nil
        end
      end

      def pid_path
        path = @pidfile
        path ||= @app.configuration.pidfile
        path ||= '/var/run/tootsie.pid'
      end

      def with_lifecycle_logging(prefix, &block)
        logger.info("#{prefix} starting")
        yield
      rescue SystemExit, Interrupt, SignalException
        logger.info("#{prefix} signaled")
      rescue => e
        if logger.respond_to?(:exception)
          logger.exception(e)
        else
          logger.error("#{prefix} failed with exception #{e.class}: #{e}")
        end
        sleep(1)
        exit(1)
      end

      def logger
        @app.logger
      end

  end

end
