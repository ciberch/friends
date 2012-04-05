require 'rubygems'
require 'net/http'
require 'uri'
require 'thread'
require 'hmac-sha1'
require 'json'
require "cgi/util"

module DOL
    API_URL = 'V1'
    API_VALID_ARGUMENTS = %w[top skip select orderby filter]

    # This class handles storing the host, API key, and SharedSecret for your
    # DataRequest objects.  A DataContext is valid if it has values for host, key, and secret.
    class DataContext
        attr_accessor :host, :key, :secret, :url

        def initialize host, key, secret
          @host, @key, @secret = host, key, secret
          @url = API_URL
        end

        def valid?
          !!(@host and @key and @secret and @url)
        end
    end

    # This class handles requesting data using the API.
    # All DataRequest objects must be initialized with a DataContext
    # that provides the DatRequest with a host, API key and SharedSecret.
    # After generating a request, call #call_api to submit it.
    class DataRequest
        attr_accessor :context, :redis

        def initialize context
            @context = context
            @mutex = Mutex.new
            @active_requests = []
        end

        # This method consturcts and submits the data request.
        # It calls the passed block when it completes, returning both a result and an error.
        # If error is not nil, there was an error during processing.
        # The request is submitted in another thread, so call #wait_until_finished to ensure
        # that all requests have processed after submitting a request.
        # You can make multiple requests with #call_api from a single DataRequest object,
        # and #wait_until_finished wll correctly wait for all of them.
        def call_api method, arguments = {}, &block
            # Ensures only a valid DataContext is used
            unless @context.is_a? DataContext
              block.call nil, 'A context object was not provided.'
              return
            end

            unless @context.valid?
              block.call nil, 'A valid context object was not provided.'
              return
            end

            url = get_url(method, arguments)
            timestamp = DOL.timestamp

            redis_key = redis_cache_key(url)

            # Creates a new thread, creates an authenticated request, and requests data from the host
            @mutex.synchronize do
              @active_requests << Thread.new do
                clean = nil

                if @redis and @redis.exists(redis_key)
                  clean = @redis.get(redis_key)
                end

                unless clean
                  request = Net::HTTP::Get.new [url.path, url.query].join '?'
                  header = get_header(url,timestamp)
                  request.add_field 'Authorization', header
                  request.add_field 'Accept', 'application/json'

                  result = Net::HTTP.start(url.host, url.port) do |http|
                    http.request request
                  end

                  if result.is_a? Net::HTTPSuccess
                    clean = result.body.gsub(/\\+"/, '"')
                    clean = clean.gsub /\\+n/, ""
                    clean = clean.gsub /\"\"\{/, "{"
                    clean = clean.gsub /}\"\"/, "}"
                    #clean = clean.gsub /\\\\u/, "\u"
                    #puts clean

                    if @redis
                      @redis.set(redis_key, clean)
                      @redis.expire(redis_key, 60 * 15)
                    end

                  else
                    clean = nil
                    AppConfig.logger.error(result.inspect)
                    block.call nil, "Error: #{result.message}"
                  end
                end

                result = []
                begin
                  if clean
                    result = JSON.parse(clean)
                    result = result['d']['getJobsListing']['items']
                  end
                rescue Exception => ex
                  AppConfig.logger.error("Invalid format for #{clean} got error parsing it #{ex}")
                  @redis.delete(redis_key) if @redis
                end
                block.call result, nil

                @mutex.synchronize do
                    @active_requests.delete Thread.current
                end
              end
          end

        end

        # Halts program until all ongoing requests sent by this DataRequest finish
        def wait_until_finished
          @active_requests.dup.each do |n|
            n.join
          end
        end

        private
        # Generates a signature using your SharedSecret and the request path
        def signature timestamp, url
          HMAC::SHA1.hexdigest @context.secret, [url.path, url.query + "&Timestamp=#{timestamp}&ApiKey=#{@context.key}"].join('?')
        end

        def get_url(method, arguments)
          # Ensures only valid arguments are used
          query = []
          arguments.each_pair do |key, value|
            query << "#{key}=#{CGI::escape value.to_s}"
          end
          url = URI.parse ["#{@context.host}/#{@context.url}/#{method}", query.join('&')].join '?'
        end

        def get_header(url, timestamp)
          # Generates timestamp and url
          "Timestamp=#{timestamp}&ApiKey=#{@context.key}&Signature=#{signature timestamp, url}"
        end

      def redis_cache_key(url)
        [url.path, url.query].join '?'
      end

    end

    def self.timestamp
      t = Time.now
      t.utc.strftime "%Y-%m-%dT%H:%M:%SZ"
    end
end

class String
    # converts date strings provided by the API (of the format /Date(milliseconds-since-Epoch)/) into Ruby Time objects
    def to_api_date
        if match /\A\/Date\((\d+)\)\/\Z/
            Time.at $1.to_i / 1000
        else
            raise TypeError, "Not a valid date format"
        end
    end
end