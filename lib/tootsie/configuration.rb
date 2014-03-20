module Tootsie

  class Configuration

    def initialize
      @ffmpeg_thread_count = 1
      @worker_count = 4
      @queue_options = {}
    end

    def update!(config)
      config = config.with_indifferent_access

      [:ffmpeg_thread_count, :worker_count, :pid_path, :log_path,
        :aws_access_key_id, :aws_secret_access_key].each do |key|
        if config.include?(key)
          value = config[key]
          value = Integer($1) rescue value
          self.send("#{key}=", value)
        end
      end
      @queue_options = (config[:queue] ||= {}).symbolize_keys
    end

    def load_from_file(file_name)
      update!(YAML.load(File.read(file_name)) || {})
    end

    attr_accessor :queue_options
    attr_accessor :ffmpeg_thread_count
    attr_accessor :pid_path
    attr_accessor :log_path
    attr_accessor :worker_count
    attr_accessor :aws_secret_access_key
    attr_accessor :aws_access_key_id

  end

end
