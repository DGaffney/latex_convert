require 'rubygems' if RUBY_VERSION < "1.9"
require 'sinatra/base'
require 'erb'
require 'pry'

class LatexConvert < Sinatra::Base
  configure do
    enable :static
    enable :sessions

    set :views, File.join(File.dirname(__FILE__), 'views')
    set :public_folder, File.join(File.dirname(__FILE__), 'public')
    set :files, File.join(settings.public_folder, 'files')
    set :unallowed_paths, ['.', '..']
  end

  helpers do
    def flash(message = '')
      session[:flash] = message
    end
  end

  before do
    @flash = session.delete(:flash)
  end

  not_found do
    return '<h1>404</h1>'
  end

  error do
    return "Error (#{request.env['sinatra.error']})"
  end

  get '/' do
    @files = Dir.entries(settings.files) - settings.unallowed_paths

    erb :index
  end
  
  post '/upload' do
    if params[:file]
      filename = params[:file][:filename]
      file = params[:file][:tempfile]

      File.open(File.join(settings.files, filename), 'wb') do |f|
        f.write file.read
      end
      new_dir = "public/files/#{filename.gsub(" ", "\\ ").gsub(".zip", "")}"
      `unzip public/files/#{filename.gsub(" ", "\\ ")} -d public/files`
      unpacked_files = `ls #{new_dir}/#{filename.gsub(" ", "\\ ").gsub(".zip", "")}`.split("\n")
      texable_files = unpacked_files.select{|f| f.include?(".tex")}
      tmp_dir = "public/files/tmp_#{rand(10000000)}"
      texable_files.each do |tex_file|
        `rubber -d --into #{new_dir} #{new_dir}/#{tex_file}`
      end
      `zip -r9 #{new_dir}`
      binding.pry
      flash 'Upload successful'
    else
      flash 'You have to choose a file'
    end

    redirect '/'
  end
end
LatexConvert.run!