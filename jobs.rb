require "sinatra/base"
require "json"
require "hashie/mash"
require "sinatra/url_for"
require "cloudfoundry/environment"
require "redis"
require "logger"

require_relative "lib/DOLDataSDK"

class AppConfig
  class << self
    attr_accessor :logger
  end
end

AppConfig.logger = Logger.new(STDOUT)

class SummerJobsApp < Sinatra::Base
  LOCAL_REDIS = {host: "127.0.0.1", port: "6379"}

  helpers Sinatra::UrlForHelper

  def initialize
    super

    @logger = AppConfig.logger
    @redis = Redis.new(CloudFoundry::Environment.redis_cnx || LOCAL_REDIS)
    @logger.info("REDIS CONFIGURED")

    begin
    @redis.ping #will raise exception ==> good so we can fail fast
    @logger.info("REDIS is UP")
    rescue
      @logger.error("REDIS is NOT RUNNING")
      @redis = nil
    end
  end

  helpers do

    def get_jobs(query='vmware')
      @jobs = []
      page = params['page'].to_i || 1
      page = 1 if page < 1
      options = {:format => "'json'", :query => "'#{query}'", :region => "", :locality => "", :skipCount => 1 + (10 * (page-1))}

      @dol_request.call_api('SummerJobs/getJobsListing', options) do |results, error|
        if error
          @logger.error(error)
        else
          results.each do |n|
            n['pagemap']['jobposting'].each_with_index do |job, i|
              job[:url] = n['pagemap']['article'][i]['url'] rescue n['link']
              @jobs << Hashie::Mash.new(job)
            end
          end
        end
      end
      @dol_request.wait_until_finished
      @jobs
    end

  end

  before do
    @appid = ENV['facebook_app_id']
    @description = "A new call-to-action for businesses, non-profits, and government to provide pathways to employment for low-income and disconnected youth in the summer of 2012"
    @context = DOL::DataContext.new('http://api.dol.gov', ENV['usdol_token'], ENV['usdol_secret'])
    @dol_request = DOL::DataRequest.new(@context)
    @dol_request.redis = @redis
  end

  get "/" do
    @jobs = get_jobs()

    @full_url = url_for("/", :full)
    @image = url_for("/images/me.png", :full)
    @title = "Summer Jobs+ 2012"
    haml :index
  end

  get "/search" do
    @full_url = url_for("/search", :full)
    @title = "Search results for #{params['q']}"
    @jobs = get_jobs(params['q'])
    haml :index
  end

  get "/search.json" do
    @full_url = url_for("/search", :full)
    @title = "Search results for #{params['q']}"
    @jobs = get_jobs(params['q'])
    @jobs.to_json
  end


  # Eager loads the app to prefetch the blog
  prototype

  run! if __FILE__ == $0
end

# Hack would be nice if this got fixed
#require 'sinatra'
