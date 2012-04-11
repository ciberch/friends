require "sinatra/base"
require "json"
require "hashie/mash"
require "sinatra/url_for"
require "cloudfoundry/environment"
require "redis"
require "logger"
require "koala"

require_relative "lib/DOLDataSDK"

class AppConfig
  class << self
    attr_accessor :logger
  end
end

AppConfig.logger = Logger.new(STDOUT)

class SummerJobsApp < Sinatra::Base
  LOCAL_REDIS = {host: "127.0.0.1", port: "6379"}
  FACEBOOK_SCOPE = 'user_location,user_birthday,user_about_me,friends_location, friends_about_me,friends_birthday, publish_actions'

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

  configure do
    set(:protection, :except => :frame_options)
    enable :sessions
  end


  # the facebook session expired! reset ours and restart the process
  error(Koala::Facebook::APIError) do
    session[:access_token] = nil
    redirect "/auth/facebook"
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


     def scheme
       request.scheme
     end

     def url_no_scheme(path = '')
       "//#{CloudFoundry::Environment.host}#{path}"
     end

     def url(path = '')
       "#{scheme}://#{CloudFoundry::Environment.host}#{path}"
     end

    def authenticator
      @authenticator ||= Koala::Facebook::OAuth.new(@appid, @appsecret, url("/auth/facebook/callback"))
    end
  end


  before do
    @appid = ENV['facebook_app_id']
    @appsecret = ENV['facebook_app_secret']
    @oauth = Koala::Facebook::OAuth.new(@appid, @appsecret)
    @description = "A new call-to-action for businesses, non-profits, and government to provide pathways to employment for low-income and disconnected youth in the summer of 2012"
    @context = DOL::DataContext.new('http://api.dol.gov', ENV['usdol_token'], ENV['usdol_secret'])
    @dol_request = DOL::DataRequest.new(@context)
    @dol_request.redis = @redis
  end

  post "/" do
    signed_request = @oauth.parse_signed_request(params["signed_request"])
    @logger.info("Got POST with #{signed_request}")
    redirect "/"
  end

  get "/" do
    if session[:access_token]
      @logger.info("We have an access token")
      @graph  = Koala::Facebook::API.new(session[:access_token])
      @user    = @graph.get_object("me")
      logger.info("User is #{@user.inspect}")
      @friends = @graph.get_connections('me', 'friends')
      logger.info("Friends are #{@friends.inspect}")
      # query jobs for friends
      @jobs = get_jobs()
    else
      @logger.info("We dont have an access token")
      @jobs = get_jobs()
    end

    @full_url = url_for("/", :full)
    @image = url_for("/images/summerjobs.png", :full)
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

  # used to close the browser window opened to post to wall/send to friends
  get "/close" do
    "<body onload='window.close();'/>"
  end

  get "/sign_out" do
    session[:access_token] = nil
    redirect '/'
  end

  get "/auth/facebook" do
    session[:access_token] = nil
    redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
  end

  get "/auth/facebook/callback" do
    session[:access_token] = authenticator.get_access_token(params[:code])
    redirect '/'
  end


  # Eager loads the app to prefetch the blog
  prototype

  run! if __FILE__ == $0
end

# Hack would be nice if this got fixed
#require 'sinatra'
