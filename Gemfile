source 'https://rubygems.org'

gem "sinatra"
gem "sinatra-contrib"
gem "shotgun"
gem "compass"
gem "rest-client"
gem "data_mapper"
gem 'dm-validations'

group :development, :test do
    gem "sqlite3"
    gem "dm-sqlite-adapter"
end

group :production do
  gem "pg"
  gem "dm-postgres-adapter"
end