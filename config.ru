require 'sinatra'
require 'rack'
set :env,  :production
disable :run

require './app.rb'    #the app itself

run Sinatra::Application

