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
    if (Gist.count(:id => params[:id]) === 0)
      if defined?(settings.github["username"]) and defined?(settings.github["pasword"])
        http    = RestClient.get "https://" + settings.github["username"] + ":" + settings.github["password"] + "@api.github.com/gists/#{params[:id]}"
      else
        http    = RestClient.get "https://api.github.com/gists/#{params[:id]}"
      end
      @sgist = Gist.create(
        :id       => params[:id],
        :content  => http,
      )
    else
      if defined?(settings.github["username"]) and defined?(settings.github["pasword"])
        http    = RestClient.get "https://" + settings.github["username"] + ":" + settings.github["password"] + "@api.github.com/gists/#{params[:id]}"
        puts http.headers
      else
        http    = RestClient.get "https://api.github.com/gists/#{params[:id]}"
      end      
      http = Gist.get(params[:id]).content
    end
    json      = JSON.parse(http)
    @html_url = json['html_url']
    markdown  = json['files'].first[1]['content']
    markup    = RestClient.post 'https://api.github.com/markdown/raw', markdown, :content_type => 'text/plain'
    @title    = "Gist #{params[:id]}"
    @font_url = settings.hfj["url"] unless !defined?(settings.hfj["url"])
    @markup   = markup
    erb :index
  end
end

def request_gist(id)

end