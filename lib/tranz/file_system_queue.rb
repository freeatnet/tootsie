require 'json'
require 'tempfile'
require 'fileutils'

module Tranz

  # A simple, naive job queue implementation that stores items as JSON files 
  # in the file system.
  class FileSystemQueue
    
    def initialize(directory)
      @directory = directory
      FileUtils.mkdir_p(@directory)
    end
    
    def push(job)
      Tempfile.open('tranz') do |tempfile|
        tempfile << job.to_json
        tempfile.close
        FileUtils.mv(tempfile.path, File.join(@directory, "#{Time.now.to_f}.json"))
      end
    end
    
    def pop(options = {})
      loop do
        lock do
          file_name = Dir.glob(File.join(@directory, "*.json")).sort.first
          if file_name
            job_data = JSON.parse(File.read(file_name))
            FileUtils.rm(file_name)
            return Job.new(job_data)
          end
        end
        if options[:wait]
          sleep(1.0)
        else
          return nil
        end
      end
    end
    
    private
    
      def lock
        lock_file_name = File.join(@directory, "lock");
        begin
          FileUtils.mkdir(lock_file_name)
        rescue Errno::EEXIST
          sleep(0.2)
          retry
        end
        begin
          yield
        ensure
          FileUtils.rmdir(lock_file_name)
        end
      end
    
  end
  
end
