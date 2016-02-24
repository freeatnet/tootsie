module Tootsie
  module Resources

    class FileResource

      def initialize(path)
        @path = path
        @content_type = nil
      end

      def open(mode = 'r')
        close
        case mode
          when 'r', 'w'
            begin
              @file = File.open(@path, "#{mode}b")
            rescue Errno::ENOENT
              raise ResourceNotFound, "Path #{@path} does not exist"
            end
          else
            raise ArgumentError, "Invalid mode: #{mode.inspect}"
        end
        @file
      end

      def close
        if @file
          @file.close if not @file.closed?
          @file = nil
        end
      end

      def save
        close
      end

      def public_url
        nil
      end

      def url
        "file://#{@path}"
      end

      attr_accessor :content_type
      attr_reader :file

    end

  end
end
