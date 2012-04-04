require "sinatra"
require "json"
require "hashie/mash"
require "sinatra/url_for"
require_relative "lib/DOLDataSDK"

before do
  @appid = ENV['facebook_app_id']
  @description = "A new call-to-action for businesses, non-profits, and government to provide pathways to employment for low-income and disconnected youth in the summer of 2012"
end

get "/" do
  @jobs = []
  options = {:format => 'json', :query => 'Developer', :region => '94107', :locality => 'San Francisco', :skipCount => 1}
  begin
    @context = DOL::DataContext.new('http://api.dol.gov', ENV['usdol_token'], ENV['usdol_secret'])
    @dol_request = DOL::DataRequest.new(@context)
    @dol_request.call_api('SummerJobs/getJobsListing', options) do |results, error|
      if error
        #raise error
      else
        results.each do |n|
            @jobs << Hashie::Mash.new(n)
        end
      end
    end
    @dol_request.wait_until_finished
  rescue
  end

  @full_url = url_for("/", :full)
  @image = url_for("/images/me.png", :full)
  @title = "Summer Jobs+ 2012"
  haml :index
end

get "/search" do
  @full_url = url_for("/search", :full)
  @title = "Search results for #{params['q']}"
  @jobs = []
  haml :index
end


