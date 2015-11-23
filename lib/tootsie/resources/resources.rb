module Tootsie
  module Resources

    class ResourceError < StandardError; end

    class PermanentError < ResourceError; end
    class UnsupportedResourceTypeError < PermanentError; end
    class InvalidUriError < PermanentError; end
    class ResourceNotFound < PermanentError; end
    class TooManyRedirects < PermanentError; end
    class ResourceUnavailable < PermanentError; end
    class ResourceEmpty < PermanentError; end

    class TemporaryError < ResourceError; end
    class ResourceTemporarilyUnavailable < TemporaryError; end
    class UnexpectedResponse < TemporaryError; end

    # Parses an URI into a resource object. The resource object will support the
    # following methods:
    #
    # * +open(mode)+ - returns a +stream+ with a +file_name+. +mode+ is either 'r' or 'w'.
    # * +close+ - closes the stream.
    # * +file+ - the open file, if any.
    # * +content_type+ (r/w) - content type of the file, if open.
    # * +save+ - replaces the resource with the current stream.
    # * +public_url+ - public HTTP URL of resource, which may not be the same as
    #   resource itself.
    #
    def self.parse_uri(uri)
      uri = URI.parse(uri) if uri.respond_to?(:to_str)
      case uri.try(:scheme)
        when 'file'
          FileResource.new(uri.path)
        when 'http', 'https'
          HttpResource.new(uri)
        when 's3'
          S3Resource.new(uri.to_s)
        when nil
          raise InvalidUriError, "Resource URI cannot be nil"
        else
          raise UnsupportedResourceTypeError, "Unsupported resource: #{uri.inspect}"
      end
    rescue URI::Error => e
      raise InvalidUriError, "Not a valid resource URL: #{uri}"
    end

  end
end
