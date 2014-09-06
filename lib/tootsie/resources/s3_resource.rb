require 'benchmark'

module Tootsie
  module Resources

    class S3Resource

      include PrefixedLogging

      def initialize(uri)
        @uri = uri
        @options = S3Utilities.parse_uri(uri)
      end

      def open(mode = 'r')
        close
        case mode
          when 'r'
            begin
              object = s3.buckets.
                find(@options[:bucket]).objects.find(@options[:key])
              object.send(:get_object) unless object.content  # Work around issue with s3 gem

              @temp_file = Tempfile.open('tootsie')
              @temp_file.write(object.content)
              @temp_file.seek(0)
            rescue ::S3::Error::NoSuchBucket, ::S3::Error::NoSuchKey
              raise ResourceNotFound, @uri
            end
          when 'w'
            @temp_file = Tempfile.open('tootsie')
          else
            raise ArgumentError, "Invalid mode: #{mode.inspect}"
        end
        @temp_file
      end

      def close
        if @temp_file
          @temp_file.close if not @temp_file.closed?
          @temp_file = nil
        end
      end

      def save
        return unless @temp_file
        begin
          @temp_file.seek(0)

          logger.info "Uploading to #{@uri} (#{@temp_file.size} bytes)"

          elapsed_time = Benchmark.realtime {
            object = s3.buckets.
              find(@options[:bucket]).objects.build(@options[:key])
            object.acl = @options[:acl] || :private
            object.content_type = @options[:content_type] || @content_type
            object.storage_class = @options[:storage_class] || :standard
            object.content = @temp_file
            object.save
          }

          logger.info "Upload took #{elapsed_time.round(3)} seconds"
        rescue ::S3::Error::NoSuchBucket
          raise ResourceNotFound, "Bucket #{@options[:bucket].inspect} not found"
        end
        close
      end

      def public_url
        s3.buckets.
          find(@options[:bucket]).objects.find(@options[:key]).url
      end

      def file
        @temp_file
      end

      def url
        @uri
      end

      attr_accessor :content_type

      private

        def s3
          @s3 ||= Tootsie::Configuration.instance.s3_service
        end

    end

  end
end