module Tootsie
  module Resources

    class HttpResource

      def initialize(uri)
        @uri = uri
      end

      def open(mode = 'r')
        case mode
          when 'r'
            visited, uri = Set.new, @uri.to_s
            loop do
              close
              response = Excon.get(uri,
                :headers => {'Accept' => '*/*'},
                :response_block => proc { |chunk, remaining_bytes, total_bytes|
                  @temp_file = Tempfile.open('tootsie')
                  @temp_file.write(chunk)
                })
              case response.status
                when 200
                  @content_type = response.headers['Content-Type']
                  @temp_file ||= Tempfile.open('tootsie')  # In case of empty stream
                  @temp_file.seek(0)
                  break
                when 301, 302
                  location = response.headers['Location']
                  if location.nil?
                    raise ResourceNotFound
                  elsif not visited.add?(location)
                    raise TooManyRedirects
                  else
                    uri = location
                  end
                when 404
                  raise ResourceNotFound
                else
                  raise UnexpectedResponse, "Server returned status #{response.status} for #{uri}"
              end
            end
          when 'w'
            close
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
        @temp_file.seek(0)
        response = Excon.post(@uri.to_s,
          :body => @temp_file,
          :headers => {'Content-Type' => @content_type || 'application/octet-stream'})
        unless (200..399).include?(response.status)
          raise UnexpectedResponse,
            "Server returned status #{response.status} when trying to POST to #{uri}"
        end
        close
      end

      def file
        @temp_file
      end

      def url
        @uri.to_s
      end
      alias_method :public_url, :url

      attr_accessor :content_type

    end

  end
end