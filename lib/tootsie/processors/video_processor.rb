require 'json'

module Tootsie
  module Processors

    class VideoProcessor

      include PrefixedLogging

      def initialize(params = {})
        @input = Resources.parse_uri(params[:input_url])
        @thumbnail_options = (params[:thumbnail] || {}).with_indifferent_access
        @versions = [params[:versions] || {}].flatten
        @thread_count = Configuration.instance.ffmpeg_thread_count
      end

      def params
        return {
          :input_url => @input.url,
          :thumbnail => @thumbnail_options,
          :versions => @versions
        }
      end

      def execute!(&block)
        result = {:urls => []}
        output, thumbnail_output = nil, nil
        begin
          @input.open
          begin
            versions.each_with_index do |version_options, version_index|
              version_options = version_options.with_indifferent_access

              if version_index == 0 and @thumbnail_options[:target_url]
                thumbnail_output = Resources.parse_uri(@thumbnail_options[:target_url])
              else
                thumbnail_output = nil
              end
              begin
                output = Resources.parse_uri(version_options[:target_url])
                begin
                  output.open('w')

                  if version_options[:strip_metadata]
                    # This actually strips in-place, so no need to swap streams
                    CommandRunner.new("id3v2 --delete-all '#{@input.file.path}'").run do |line|
                      if line.present? and line !~ /\AStripping id3 tag in.*stripped\./
                        logger.warn "ID3 stripping failed, ignoring: #{line}"
                      end
                    end
                  end

                  adapter_options = version_options.dup
                  adapter_options.delete(:target_url)
                  if thumbnail_output
                    thumbnail_output.open('w')
                    adapter_options[:thumbnail] = @thumbnail_options.merge(
                      :filename => thumbnail_output.file.path)
                  else
                    adapter_options.delete(:thumbnail)
                  end

                  adapter = Tootsie::FfmpegAdapter.new(:thread_count => @thread_count)
                  if block
                    adapter.progress = lambda { |seconds, total_seconds|
                      yield(:progress => (seconds + (total_seconds * version_index)) / (total_seconds * versions.length).to_f)
                    }
                  end
                  adapter.transcode(@input.file.path, output.file.path, adapter_options)

                  output.content_type = version_options[:content_type] if version_options[:content_type]
                  output.save

                  result[:urls].push output.public_url
                ensure
                  output.close
                end
                if thumbnail_output
                  thumbnail_output.save
                  result[:thumbnail_url] = thumbnail_output.public_url
                end
              ensure
                thumbnail_output.try(:close)
              end
            end
          end
        ensure
          @input.close
        end
        result
      end

      attr_accessor :input_url
      attr_accessor :versions
      attr_accessor :thumbnail_options

    end

  end
end
