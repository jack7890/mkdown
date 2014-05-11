require 'rubygems'
require 'sinatra'
require 'sinatra/config_file'
require 'compass'
require 'rest_client'
require 'json'
require 'data_mapper'
require 'dm-sqlite-adapter'

config_file './config.yml'

set :run, true
set :views, File.dirname(__FILE__) + "/views"

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/mkdown.db")

configure do
  set :scss, {:style => :compact, :debug_info => false}
  Compass.add_project_configuration(File.join(Sinatra::Application.root, '/', 'config.rb'))
end

class Gist 
  include DataMapper::Resource

  property :id,       Text, :key => true
  property :content,  Text
  property :markup,   Text
  property :etag,     Text
end

DataMapper.finalize

get '/' do
  redirect settings.home_gist
end

get '/stylesheets/:name.css' do
  content_type 'text/css', :charset => 'utf-8'
  scss(:"stylesheets/#{params[:name]}" )
end

['/:id', '/g/:id'].each do |path|
  get path do
    # Check to see if this gist has ever been stored in the db
    if (Gist.count(:id => params[:id]) === 0)
      # If it hasn't been stored in the db, request it and store the result
      http = request_gist(params[:id])
      @sgist = Gist.create(
        :id       => params[:id],
        :content  => http,
        :etag     => http.headers[:etag]
      )
    else
      # If the gist has been stored in the db, check to see if the etag has changed
      if defined?(settings.github["username"]) and defined?(settings.github["pasword"])
        authenticated = true
      else
        authenticated = false
      end
      http, cached = request_gist_with_etag(params[:id], authenticated)
    end
    json      = JSON.parse(http)
    @html_url = json['html_url']
    markdown  = json['files'].first[1]['content']
    @title    = "Gist #{params[:id]}"
    @font_url = settings.hfj["url"] unless !defined?(settings.hfj["url"])
    if (cached)
      @markup = Gist.get(params[:id]).markup
    else
      @markup = get_markup(markdown)
      gist = Gist.get(params[:id])
      gist.update(:markup => @markup)
    end
    erb :index
  end
end

def get_markup(markdown)
  if defined?(settings.github["username"]) and defined?(settings.github["pasword"])
    markdown = RestClient.post "https://" + settings.github["username"] + ":" + settings.github["password"] + "@api.github.com/markdown/raw", markdown, :content_type => 'text/plain'
  else
    markdown = RestClient.post 'https://api.github.com/markdown/raw', markdown, :content_type => 'text/plain'
  end
  return markdown
end

def request_gist(id)
  if defined?(settings.github["username"]) and defined?(settings.github["pasword"])
    http = RestClient.get "https://" + settings.github["username"] + ":" + settings.github["password"] + "@api.github.com/gists/#{id}"
  else
    http = RestClient.get "https://api.github.com/gists/#{id}"
  end
  return http
end

def request_gist_with_etag(id, authenticated)
  etag = Gist.get(id).etag
  url = 
    if (authenticated)
      "https://" + settings.github["username"] + ":" + settings.github["password"] + "@api.github.com/gists/#{params[:id]}"
    else
      "https://api.github.com/gists/#{params[:id]}"
    end
  begin
    http = RestClient::Request.execute(
      :method   => :get,
      :url      => url,
      :headers  => {'If-None-Match' => "#{etag}"}
    )
    gist = Gist.get(params[:id])
    gist.update(:etag => http.headers[:etag])
    cached = false
  rescue RestClient::NotModified
    http = Gist.get(params[:id]).content
    cached = true
  end
  return http, cached
end