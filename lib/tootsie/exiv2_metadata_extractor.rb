module Tootsie

  # Uses external exiv2 tool.
  class Exiv2MetadataExtractor

    include PrefixedLogging

    def initialize
      @metadata = {}
    end

    def self.available?
      IO.popen("exiv2 --help >/dev/null 2>&1", 'r') { |f| f.read }
      $?.exitstatus == 0
    end

    def extract_from_file(file_name)
      run_exiv2("-pt :file", :file => file_name) do |line|
        parse_exiv2_line(line)
      end
      run_exiv2("-pi :file", :file => file_name) do |line|
        parse_exiv2_line(line)
      end
      run_exiv2("-px :file", :file => file_name) do |line|
        parse_exiv2_line(line)
      end
      @metadata = Hash[*@metadata.entries.map { |key, values|
        [key, values.length > 1 ? values : values.first]
      }.flatten(1)]
      @metadata
    end

    attr_reader :metadata

    private

      def run_exiv2(args, params, &block)
        CommandRunner.new("exiv2 #{args}",
          :output_encoding => 'ascii-8bit',
          :ignore_exit_code => true
        ).run(params, &block)
      end

      def parse_exiv2_line(line)
        if line =~ /^([^\s]+)\s+([^\s]+)\s+\d+  (.*)$/
          key, type, value = $1, $2, $3
          unless value.blank?
            case type
              when 'Short', 'Long'
                value = value.to_i
              when 'Date'
                begin
                  value = Time.parse(value)
                rescue Exception => e
                  logger.warn "Invalid time format in EXIF data, ignoring value: #{value.inspect}"
                  value = nil
                end
              else
                value = decode_string(value)
            end
            if value
              entry = {:value => value, :type => type.underscore}
              (@metadata[key] ||= []) << entry
            end
          end
        end
      end

      def decode_string(value)
        if value.respond_to?(:force_encoding)  # Ruby 1.9
          utf8 = value.dup.force_encoding('utf-8')
          if utf8.valid_encoding?
            value = utf8
          else
            begin
              value = value.encode('utf-8', 'iso-8859-1')
            rescue EncodingError
              logger.warn "Invalid characters in EXIF data that are neither UTF-8 nor ISO-8859-1, ignoring it: #{value.inspect}"
              value = nil
            end
          end
        else  # Ruby 1.8
          require 'iconv'
          begin
            Iconv.iconv("utf-8", "utf-8", value)
          rescue Iconv::IllegalSequence, Iconv::InvalidCharacter
            begin
              value = Iconv.iconv("utf-8", "iso-8859-1", value)[0]
            rescue Exception => e
              logger.warn "Invalid encoding in EXIF data, ignoring value: #{value.inspect}"
              value = nil
            end
          end
        end
        value
      end

  end

end