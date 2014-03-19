module Tootsie
  module Resources

    class ResourceError < StandardError; end
    class UnsupportedResourceTypeError < ResourceError; end
    class InvalidUriError < ResourceError; end
    class ResourceNotFound < ResourceError; end
    class TooManyRedirects < ResourceError; end
    class UnexpectedResponse < ResourceError; end
    class ResourceTemporarilyUnavailable < ResourceError; end

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
        else
          raise UnsupportedResourceTypeError, "Unsupported resource: #{uri.inspect}"
      end
    end

  end
end
