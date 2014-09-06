module Tootsie

  # A queue which uses the AMQP protocol.
  class Queue

    def initialize(options = {})
      options.assert_valid_keys(:host_name, :queue_name, :exchange_name, :max_backoff)
      @backoff = Utility::Backoff.new(:max => options[:max_backoff])
      @logger = Application.get.logger
      @host_name = options[:host_name] || 'localhost'
      @exchange_name = options[:exchange_name] || 'tootsie'
      @queue_name = options[:queue_name] || 'tootsie'
      @routing_key = 'tootsie'
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
          @exchange.publish(data, persistent: true, key: @routing_key)
        end
      end
    end

    def consume(&block)
      loop do
        @backoff.with do
          delivery_info, metadata, payload = with_retry {
            with_connection {
              @queue.pop(ack: true)
            }
          }
          if payload
            @logger.info { "Consuming: #{payload.inspect}" }
            begin
              yield JSON.parse(payload)
            rescue => e
              with_connection do
                @queue.channel.nack(delivery_info.delivery_tag, false, true)
              end
              raise e
            else
              with_connection do
                @queue.channel.ack(delivery_info.delivery_tag)
              end
            end
            true
          else
            false
          end
        end
      end
      nil
    end

    private

      BUNNY_EXCEPTIONS = [
        Bunny::ServerDownError,
        Bunny::ConnectionError,
        Bunny::ProtocolError,
        Bunny::ClientTimeout
      ]

      def with_connection(&block)
        begin
          connect!
          result = yield
        rescue *BUNNY_EXCEPTIONS => e
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
          unless @session
            @logger.info "Connecting to AMQP server on #{@host_name}"
            @session = Bunny.new(:host => @host_name)
            @session.start

            @channel = @session.create_channel
          end

          unless @exchange
            @exchange = @session.exchange(@exchange_name,
              type: :topic, durable: true)
          end

          unless @queue
            @queue = @session.queue(@queue_name, durable: true)
          end
          @queue.bind(@exchange_name, key: @routing_key)
        rescue Bunny::ServerDownError => e
          @logger.error "Could not connect: #{e}"
          sleep(0.5)
          retry
        end
      end

      def reset_connection
        @channel = nil
        @queue = nil
        @exchange = nil
        if @session
          @session.close rescue nil
          @session = nil
        end
      end

  end

end
