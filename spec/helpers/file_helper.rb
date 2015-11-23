module FileHelper

  def test_file_path(path)
    File.expand_path("../../test_files/#{path}", __FILE__)
  end

  def test_file_url(path)
    "file:#{test_file_path(path)}"
  end

  def test_data(name)
    File.read(test_file_path(name), encoding: 'binary')
  end

end