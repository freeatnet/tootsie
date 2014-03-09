module Tootsie

  # A queue which uses the AMQP protocol.
  class Queue

    def initialize(options = {})
      options.assert_valid_keys(:host_name, :queue_name, :max_backoff)
      @backoff = Utility::Backoff.new(:max => options[:max_backoff])
      @logger = Application.get.logger
      @host_name = options[:host_name] || 'localhost'
      @name = options[:queue_name] || 'tootsie'
    end

    def count
      with_connection do
        if @queue && (status = @queue.status)
          status[:message_count]
        else
          nil
        end
      end
    end

    def push(message)
      data = message.to_json
      with_retry do
        with_connection do
          @exchange.publish(data, persistent: true, key: @name)
        end
      end
    end

    def consume(&block)
      loop do
        @backoff.with do
          message = nil
          with_retry do
            with_connection do
              message = @queue.pop(ack: true)
            end
          end
          if message
            data = message[:payload]
            if data and data != :queue_empty
              @logger.info { "Consuming: #{data.inspect}" }
              message = JSON.parse(data)
              yield message
              with_connection do
                @queue.ack(delivery_tag: message[:delivery_details][:delivery_tag])
              end
            end
          end
        end
      end
      nil
    end

    private

      def with_connection(&block)
        begin
          connect!
          result = yield
        rescue Bunny::ServerDownError, Bunny::ConnectionError, Bunny::ProtocolError => e
          @logger.error "Error in AMQP server connection (#{e.class}: #{e}), retrying"
          reset_connection
          sleep(0.5)
          retry
        else
          result
        end
      end

      def with_retry(&block)
        begin
          result = yield
        rescue => e
          @logger.error("Queue access failed with exception #{e.class} (#{e.message}), will retry")
          sleep(0.5)
          retry
        else
          result
        end
      end

      def connect!
        begin
          unless @connection
            @logger.info "Connecting to AMQP server on #{@host_name}"
            @connection = Bunny.new(:host => @host_name)
            @connection.start
          end

          unless @exchange
            @exchange = @connection.exchange('')
          end

          unless @queue
            @queue = @connection.queue(@name, :durable => true)
          end
        rescue Bunny::ServerDownError => e
          @logger.error "Could not connect: #{e}"
          sleep(0.5)
          retry
        end
      end

      def reset_connection
        if @connection
          @connection.close rescue nil
          @connection = nil
        end
        @queue = nil
        @exchange = nil
      end

  end

end
