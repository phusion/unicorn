# encoding: binary
require 'zlib'

module Unicorn
  class StreamingHelper
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
      if headers['Transfer-Encoding'] == 'chunked'
        headers['X-Accel-Buffering'] = 'no'
        headers.delete('Transfer-Encoding')
        if should_compress?(headers)
          headers['Content-Encoding'] = 'gzip'
          body = DechunkedBody.new(body, true)
        else
          body = DechunkedBody.new(body, false)
        end
      end
      [status, headers, body]
    end
    
  private
    def should_compress?(headers)
      content_type = headers['Content-Type']
      if content_type
        content_type = content_type.downcase
        content_type.sub!(/;.*/, '')
        @compression_type_names[content_type] ||
          @compression_type_regexps.one? do |regexp|
            content_type =~ regexp
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