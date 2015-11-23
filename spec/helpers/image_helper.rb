module ImageHelper

  def process_image_version(test_file_name, version)
    result, content = nil, nil
    Tempfile.open("specs", :encoding => 'binary') do |file|
      file.close

      version[:target_url] = "file:#{file.path}"

      proc = ImageProcessor.new(
        :input_url => test_file_url(test_file_name),
        :versions => [version])

      result = proc.execute!
      expect(result).to have_key(:outputs)
      expect(result[:outputs].length).to eq 1
      expect(result[:outputs][0]).to have_key(:url)

      content = File.read(file.path, encoding: 'binary')
      expect(content.length).to be > 0
    end
    [result, content]
  end

  def extract_dimensions(image_data)
    Tempfile.open("specs", :encoding => 'binary') do |file|
      file << image_data
      file.close
      IO.popen("identify -format '%w %h %[EXIF:Orientation]' '#{file.path}'", 'r') do |f|
        f.each_line do |line|
          if line =~ /(\d+) (\d+) (\d*)/
            width, height, orientation = $1.to_i, $2.to_i, $3.to_i
            if [5, 6, 7, 8].include?(orientation)
              width, height = height, width
            end
            return width, height
          end
        end
      end
    end
  end

end
