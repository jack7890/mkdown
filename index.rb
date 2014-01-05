require 'rubygems'
require 'sinatra'
require 'sinatra/config_file'
require 'compass'
require 'rest_client'
require 'json'

config_file './config.yml'

set :run, true
set :views, File.dirname(__FILE__) + "/views"

configure do
  set :scss, {:style => :compact, :debug_info => false}
  Compass.add_project_configuration(File.join(Sinatra::Application.root, '/', 'config.rb'))
end

get '/' do
  redirect settings.home_gist
end

get '/stylesheets/:name.css' do
  content_type 'text/css', :charset => 'utf-8'
  scss(:"stylesheets/#{params[:name]}" )
end

['/:id', '/g/:id'].each do |path|
  get path do
    if defined?(settings.github["username"]) and defined?(settings.github["pasword"])
      http    = RestClient.get "https://" + settings.github["username"] + ":" + settings.github["password"] + "@api.github.com/gists/#{params[:id]}"
    else
      http    = RestClient.get "https://api.github.com/gists/#{params[:id]}"
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