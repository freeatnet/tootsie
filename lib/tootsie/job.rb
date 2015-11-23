module Tootsie
  class Job

    include PrefixedLogging

    DEFAULT_MAX_RETRIES = 5

    VALID_TYPES = %w(video audio image).freeze

    class InvalidJobError < StandardError; end

    def initialize(attributes = {})
      attributes = attributes.symbolize_keys
      attributes.assert_valid_keys(
        :uid, :type, :retries, :notification_url, :params, :reference)

      @type = attributes[:type].try(:to_s)
      @uid = attributes[:uid]
      @retries_left = attributes[:retries] || DEFAULT_MAX_RETRIES
      @created_at = attributes[:created_at] || Time.now
      @created_at = Time.parse(@created_at) if @created_at.is_a?(String)
      @notification_url = attributes[:notification_url]
      @params = (attributes[:params] || {}).with_indifferent_access
      @reference = attributes[:reference]
    rescue ArgumentError => e
      raise InvalidJobError, e.message
    end

    def publish
      Configuration.instance.river.publish(
        uid: @uid,
        event: 'tootsie.job',
        type: @type,
        notification_url: @notification_url,
        retries: @retries_left,
        reference: @reference,
        params: @params)
    end

    def valid?
      @uid && @type && VALID_TYPES.include?(@type)
    end

    def notify(what, data = {})
      event = {
        uid: @uid,
        event: "tootsie.#{what}"
      }
      event.merge!(data)
      event[:reference] = @reference if @reference
      event[:type] = @type
      event[:params] = @params

      notification_url = @notification_url
      if notification_url
        event_json = event.to_json

        logger.info { "Notifying #{notification_url} with event: #{event_json}" }
        begin
          Excon.post(notification_url,
            :body => event_json,
            :headers => {'Content-Type' => 'application/json; charset=utf-8'})
        rescue => exception
          Configuration.instance.report_exception(exception,
            "Notification to #{notification_url} failed with exception")
        end
      else
        logger.info { "Publishing event: #{event.inspect}" }
        Configuration.instance.river.publish(event)

        if event == :completed and Configuration.instance.use_legacy_completion_event
          # TODO: Legacy event name, for backwards compatibility
          Configuration.instance.river.publish(event.merge(event: 'tootsie_completed'))
        end
      end
    end

    def eql?(other)
      other.is_a?(Job) &&
        other.created_at == @created_at &&
        other.notification == @notification &&
        other.params == @params &&
        other.reference == @reference &&
        other.type == @type &&
        other.uid == @uid
      attributes == other.attributes
    end
    alias_method :==, :eql?

    attr_accessor :retries_left

    attr_reader :created_at
    attr_reader :notification_url
    attr_reader :params
    attr_reader :type
    attr_reader :reference
    attr_reader :uid

    private

      def logger_prefix
        "#{super} #{@uid}"
      end

  end
end
