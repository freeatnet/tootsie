module Tootsie
  class FfmpegError < StandardError; end

  class FfmpegAdapter
    include PrefixedLogging

    FFMPEG_BINARY = 'ffmpeg'

    def initialize(input_filename, options = {})
      @ffmpeg_arguments = {}
      @ffmpeg_arguments['i'] = input_filename

      @ffmpeg_arguments['threads'] = (options[:thread_count] || 1)

      # ffmpeg only requires level 1 to get stream info, but libav's ffmpeg
      # tool requires a higher level.
      @ffmpeg_arguments['v'] = 99

      # Overwrite existing output files
      @ffmpeg_arguments['y'] = true
    end

    # Transcode a file by taking an input file and writing an output file.
    def transcode(output_filename, options = {})
      probe! unless probed?

      arguments = @ffmpeg_arguments.dup
      if options[:audio_codec].to_s == 'none'
        arguments['an'] = true
      else
        case options[:audio_codec].try(:to_s)
          when 'aac'
            arguments['acodec'] = 'libfaac'
          when String
            arguments['acodec'] = options[:audio_codec]
        end
        arguments['ar'] = options[:audio_sample_rate] if options[:audio_sample_rate]
        arguments['ab'] = options[:audio_bitrate] if options[:audio_bitrate]
      end
      if options[:video_codec].to_s == 'none'
        arguments['vn'] = true
      else
        case options[:video_codec].try(:to_s)
          when 'h264'
            arguments['vcodec'] = 'libx264'
            arguments['vpre'] = ['medium', 'main']  # TODO: Allow override
            arguments['crf'] = 15                   # TODO: Allow override
            arguments['threads'] = 0
          when String
            arguments['vcodec'] = options[:video_codec]
        end
        arguments['b'] = options[:video_bitrate] if options[:video_bitrate]
        arguments['r'] = options[:video_frame_rate] if options[:video_frame_rate]
        arguments['s'] = "#{options[:width]}x#{options[:height]}" if options[:width] or options[:height]

        quality = options[:quality].try(:to_f)
        quality ||= 1.0
        quality = [[quality, 1.0].min, 0.0].max
        arguments['qscale'] = 1 + (1 - quality) * 30  # 1..31
      end
      arguments['f'] = options[:format] if options[:format]

      progress, expected_duration, final_duration, stream_count,
        error_count = @progress, nil, nil, 0, 0
      result_width, result_height = nil
      run_ffmpeg(output_filename, arguments) do |line|
        case line
          when /^Input #\d/
            stream_count += 1
          when /^\s*Duration: (\d+):(\d+):(\d+)\./
            unless expected_duration
              hours, minutes, seconds = $1.to_i, $2.to_i, $3.to_i
              expected_duration = seconds + minutes * 60 + hours * 60 * 60
            end
          when /^frame=.* time=(\d+)\./
            if expected_duration
              elapsed_time = $1.to_i
            end
          when /^size=.*time=(\d+):(\d+):(\d+)\./
            hours, minutes, seconds = $1.to_i, $2.to_i, $3.to_i
            final_duration = seconds + minutes * 60 + hours * 60 * 60
          when /^size=.*time=(\d+\.\d+)/
            final_duration = $1.to_f
          when /Stream.*Video: .*, (\d+)x(\d+)\s/
            unless result_width and result_height
              result_width, result_height = $1.to_i, $2.to_i
            end
          when /^Error while decoding stream/
            error_count += 1
        end
        if progress and elapsed_time and expected_duration
          progress.call(elapsed_time, expected_duration)
        end
      end
      if error_count > 0
        if stream_count == 1 and expected_duration and final_duration
          if expected_duration.floor == final_duration.floor
            logger.warn "ffmpeg exited with error, but seems to have written complete stream."
          else
            if final_duration >= expected_duration - 1  # 1 second margin
              logger.warn "ffmpeg exited with error, but seems to have written nearly complete stream. Good enough."
            else
              raise FfmpegError, "ffmpeg failed with incomplete stream"
            end
          end
        else
          raise FfmpegError, "ffmpeg failed with errors"
        end
      end
    end

    def thumbnail(output_filename, options = {})
      probe! unless probed?

      raise FfmpegError, "The file does not contain a video stream" unless first_video_stream

      arguments = @ffmpeg_arguments.dup

      # Set thumbnail size
      width = options[:width].try(:to_i)
      height = options[:height].try(:to_i)
      if height and width and not options[:force_aspect_ratio]
        video_aspect = first_video_stream.width / first_video_stream.height.to_f
        height = (width / video_aspect).to_i
      end
      arguments['s'] = "#{width}x#{height}"

      # Set thumbnail time
      at_seconds = options[:at_seconds].try(:to_f)
      at_seconds ||= (first_video_stream.duration.to_i || 0) * (options[:at_fraction].try(:to_f) || 0.5)
      arguments['ss'] = at_seconds

      logger.info("Getting thumbnail frame (#{arguments['s']}) with FFmpeg at #{arguments['ss']} seconds")

      # Tell ffmpeg to grab one frame
      arguments['vframes'] = 1

      begin
        run_ffmpeg(output_filename, arguments)
      rescue CommandExecutionFailed => e
        logger.error("Thumbnail rendering failed: #{e}")
        raise FfmpegError, "ffmpeg thumbnailing failed"
      end
    end

    # Output captured from FFmpeg command line tool so far.
    attr_reader :output

    # Progress reporter that implements +call(seconds, total_seconds)+ to record
    # transcoding progress.
    attr_accessor :progress

    private

    def probe!
      probe
    end

    def probe
      @ffprober ||= Ffprober::Parser.from_file(@ffmpeg_arguments['i'])
    end

    def probed?
      !!@ffprober
    end

    def first_video_stream
      probe.video_streams.first
    end

    def run_ffmpeg(output_filename, arguments, &block)
      command_line = "#{FFMPEG_BINARY} "
      command_line << arguments.map { |k, v|
        case v
          when TrueClass, FalseClass
            "-#{k}"
          when Array
            v.map { |w| "-#{k} '#{w}'" }.join(' ')
          else
            "-#{k} '#{v}'"
        end
      }.join(' ')
      command_line << ' '
      command_line << "'#{output_filename}'"
      CommandRunner.new(command_line).run(&block)
    end
  end
end
