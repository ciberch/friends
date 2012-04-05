require "sinatra"
require "json"
require "hashie/mash"
require "sinatra/url_for"
require_relative "lib/DOLDataSDK"

helpers do

  def get_jobs(query='vmware')
    @jobs = []
    page = params['page'].to_i || 1
    page = 1 if page < 1
    options = {:format => "'json'", :query => "'#{query}'", :region => "", :locality => "", :skipCount => 1 + (10 * (page-1))}

    @dol_request.call_api('SummerJobs/getJobsListing', options) do |results, error|
      if error
        puts error
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


