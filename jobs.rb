require "sinatra/base"
require "thin"
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
  FACEBOOK_SCOPE = 'user_location, user_birthday, user_about_me, friends_location, friends_about_me, friends_birthday, publish_actions, friends_interests, friends_work_history, user_work_history'
  FQL = 'SELECT current_location, work, uid, name, birthday_date, is_app_user, pic_square FROM user WHERE (uid IN (SELECT uid2 FROM friend WHERE uid1 = me())) order by name'
  AGE = 30
  helpers Sinatra::UrlForHelper

  host = CloudFoundry::Environment.redis_cnx ? CloudFoundry::Environment.redis_cnx.host : LOCAL_REDIS[:host]
  port = CloudFoundry::Environment.redis_cnx ? CloudFoundry::Environment.redis_cnx.port : LOCAL_REDIS[:port]

  use Rack::Session::Cookie, :key => 'rack.session',
                             :path => '/',
                             :expire_after => 2592000, # In seconds
                             :secret => 'always happy'

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
    #enable :sessions
    set(:protection, :except => [:frame_options,  :session_hijacking] )
  end

  helpers do
    def get_jobs(query, locality, region)
      @jobs = []
      page = params['page'].to_i || 1
      page = 1 if page < 1
      region = region ? "'#{region}'" : ''
      locality = locality ? "'#{locality}'" : ''
      options = {:format => "'json'", :query => "'#{query}'", :region => region, :locality => locality, :skipCount => 1 + (10 * (page-1))}

      @dol_request.call_api('SummerJobs/getJobsListing', options) do |results, error|
        if error
          @logger.error(error)
        else
          results.each do |n|
            n['pagemap']['jobposting'].each_with_index do |job, i|
              job[:url] = n['pagemap']['article'][i]['url'] rescue n['link']
              job.keys.each do |key|
                job[key] = job[key].gsub(/\\u0027/, "'")
              end
              @jobs << Hashie::Mash.new(job)
            end
          end
        end
      end
      @dol_request.wait_until_finished
      @jobs
    end

    def get_friends(user, graph)
      friends_key = "facebook/#{user["id"]}/friends"
      friends_fql = nil
      friends = []
      older_friends = []

      if user and graph
        if @redis.exists(friends_key)
          friends_fql = JSON.parse(@redis.get(friends_key))
        else
          friends_fql = graph.fql_query(FQL)
          @redis.set(friends_key, friends_fql.to_json)
          @redis.expire(friends_key, 60 * 60 * 4)  # 4 hours
        end

        # Split friends in 2 groups by age
        friends_fql.each do |friend|
          add_job_string!(friend)
          if friend["current_location"]
            friend["location"] = "#{friend['current_location']['city']}, #{friend['current_location']['state']}"
          end
          if friend["birthday_date"] =~ /\d\d\/\d\d\/(\d\d\d\d)/
            year = $1.to_i
            if DateTime.now.year - year < AGE
              friends << friend
            else
              older_friends << friend
            end
          else
            older_friends << friend
          end
        end
      end
      [friends, older_friends]
    end

    def session
      env['rack.session']
    end

    def session=(val)
      env['rack.session'] = val
    end

    def host
      request.host
    end

     def scheme
       request.scheme
     end

     def url_no_scheme(path = '')
       "//#{host}#{path}"
     end

     def url(path = '')
       "#{scheme}://#{host}#{path}"
     end

    def authenticator
      @authenticator ||= Koala::Facebook::OAuth.new(ENV['facebook_app_id'], ENV['facebook_app_secret'], url("/auth/facebook/callback"))
    end

    def add_job_string!(user_hash)
      if user_hash and user_hash["work"] and user_hash["work"].count > 0
        job1 = user_hash["work"].first
        user_hash["job"] = job1["position"] ? job1["position"]["name"] + " @ " : ""
        user_hash["job"] += job1["employer"]["name"]
      end
    end
  end


  before do
    @description = "A new call-to-action for businesses, non-profits, and government to provide pathways to employment for low-income and disconnected youth in the summer of 2012"
    @context = DOL::DataContext.new('http://api.dol.gov', ENV['usdol_token'], ENV['usdol_secret'])
    @dol_request = DOL::DataRequest.new(@context)
    @dol_request.redis = @redis
  end

  post "/" do
    @oauth = Koala::Facebook::OAuth.new(ENV['facebook_app_id'], ENV['facebook_app_secret'])

    signed_request = @oauth.parse_signed_request(params["signed_request"])
    @logger.info("Got POST with #{signed_request}")
    session = {}
    redirect "/sign_out"
  end

  get "/" do
    @friends = []
    @user = nil

    if session and session["access_token"]
      @graph  = Koala::Facebook::API.new(session["access_token"])
      @user    = @graph.get_object("me")
      add_job_string!(@user)
      unless params['state']
        params['city'], params['state'] = @user["location"]["name"].split(", ")
      end
      @friends, @older_friends = get_friends(@user, @graph)
      params['q'] = @user['job'] ? @user['job'].gsub(/ \@/, "") : 'fun'
      # query jobs for friends
      @default_search = "/search?q=#{params['q']}&city=#{params['city']}&state=#{params['state']}"
      @full_url = url_for("/", :full)
      @image = url_for("/images/summerjobs.png", :full)
      @title = "Summer Jobs+ 2012"
      haml :index
    else
      redirect "/auth/facebook"
    end
  end

  get "/search" do
    @full_url = url_for("/search", :full)
    @title = "Search results for #{params['q']}"
    @jobs = get_jobs(params['q'], params['city'], params['state'])
    haml :jobs, :layout => :"simple-layout"
  end

  get "/search.json" do
    @full_url = url_for("/search", :full)
    @title = "Search results for #{params['q']}"
    @jobs = get_jobs(params['q'], params['city'], params['state'])
    @jobs.to_json
  end

  get "/sign_out" do
    session["access_token"] = nil
    redirect '/'
  end

  get "/auth/facebook" do
    session["access_token"] = nil
    redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
  end

  get "/auth/facebook/callback" do
    session["access_token"] = authenticator.get_access_token(params[:code])
    redirect '/'
  end


  # Eager loads the app to prefetch the blog
  prototype

  run! if __FILE__ == $0
end

# Hack would be nice if this got fixed
#require 'sinatra'
