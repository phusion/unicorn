# encoding: binary
require 'zlib'
require 'stringio'

module Unicorn
  class StreamingHelper
    TRANSFER_ENCODING = 'Transfer-Encoding'.freeze
    CONTENT_ENCODING  = 'Content-Encoding'.freeze
    X_ACCEL_BUFFERING = 'X-Accel-Buffering'.freeze
    UNICORN_SOCKET    = 'unicorn.socket'.freeze
    CONTENT_TYPE      = 'Content-Type'.freeze
    CONTENT_LENGTH    = 'Content-Length'.freeze
    CONTENT_MD5       = 'Content-MD5'.freeze
    ACCEPT_ENCODING   = 'Accept-Encoding'.freeze
    HTTP_ACCEPT_ENCODING = 'HTTP_ACCEPT_ENCODING'.freeze
    EMPTY_STRING      = ''.freeze
    VARY    = 'Vary'.freeze
    CHUNKED = 'chunked'.freeze
    GZIP    = 'gzip'.freeze
    NO      = 'no'.freeze
    
    def initialize(app, compression_types = nil)
      @app = app
      @compression_type_names = {}
      @compression_type_regexps = []
      if compression_types
        compression_types.each do |type|
          if type.is_a?(String)
            @compression_type_names[type.downcase] = true
          elsif type.is_a?(Regexp)
            @compression_type_regexps << type
          else
            raise ArgumentError, "Invalid compression type format #{type.inspect}, must be String or Regexp"
          end
        end
      end
    end
    
    def call(env)
      status, headers, body = @app.call(env)
      if headers[TRANSFER_ENCODING] == CHUNKED
        headers[X_ACCEL_BUFFERING] = NO
        headers.delete(TRANSFER_ENCODING)
        headers.delete(CONTENT_LENGTH)
        headers.delete(CONTENT_MD5)
        
        socket = env[UNICORN_SOCKET]
        socket.sync = true
        SocketHelper.set_tcp_sockopt(socket,
          :tcp_nopush => false,
          :tcp_nodelay => false)
        
        if should_compress?(env, headers)
          headers[CONTENT_ENCODING] = GZIP
          headers[VARY] = ACCEPT_ENCODING
          body = DechunkedBody.new(body, true)
        else
          body = DechunkedBody.new(body, false)
        end
      end
      [status, headers, body]
    end
    
  private
    def should_compress?(env, headers)
      content_type = headers[CONTENT_TYPE]
      if content_type
        compressable_content_type?(content_type) &&
          client_supports_compression?(env)
      else
        false
      end
    end
    
    def compressable_content_type?(content_type)
      content_type = content_type.downcase
      content_type.sub!(/;.*/, EMPTY_STRING)
      @compression_type_names[content_type] ||
        @compression_type_regexps.one? do |regexp|
          content_type =~ regexp
        end
    end
    
    def client_supports_compression?(env)
      if value = env[HTTP_ACCEPT_ENCODING]
        accept_encodings = value.split(/, */)
        accept_encodings.one? do |e|
          e =~ /\Agzip(;|\Z)/
        end
      else
        false
      end
    end
    
    class ChunkedFormatError < StandardError
      def initialize(message)
        super("Lower Rack stack generated an invalid chunked encoding response: #{message}")
      end
    end
    
    class DechunkedBody
      def initialize(body, compressed)
        @body      = body
        @dechunker = Dechunker.new
        if compressed
          @gzip_io = StringIO.new
          @gzip_io.binmode
          @gzipper = Zlib::GzipWriter.new(@gzip_io)
        end
      end
      
      def close
        @body.close if @body.respond_to?(:close)
        if @gzipper
          @gzipper.close
        end
      end
      
      def each
        @body.each do |chunk|
          if !@dechunker.accepting_input?
            # We take care of errors after feeding so here the dechunker
            # should always be in an accepting state.
            raise "BUG in #{Streaming}"
          end
          accepted = @dechunker.feed(chunk) do |data|
            if @gzip_io
              @gzipper << data
              @gzipper.flush
              yield(force_binary(@gzip_io.string))
              @gzip_io.truncate(0)
              @gzip_io.rewind
            else
              yield(data)
            end
          end
          if @dechunker.has_error?
            raise ChunkedFormatError, @dechunker.error_message
          elsif accepted != chunk.size
            raise ChunkedFormatError, "it generated more data after the terminating chunk"
          end
        end
        if @dechunker.accepting_input?
          raise ChunkedFormatError, "it is incomplete"
        end
      end
    
    private
      if ''.respond_to?(:force_binary)
        def force_binary(str)
          str.force_encoding('binary')
        end
      else
        def force_binary(str)
          str
        end
      end
    end
  end
end