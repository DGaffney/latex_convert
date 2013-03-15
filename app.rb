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
      random_name = rand(10000000).to_s
      File.open(File.join(settings.files, random_name+".zip"), 'wb') do |f|
        f.write file.read
      end
      new_dir = "public/files/#{random_name.gsub(".zip", "")}"
      `unzip public/files/#{random_name}.zip -d public/files/#{random_name}`
      unpacked_files = `ls #{new_dir}`.split("\n")-["__MACOSX"]
      texable_files = unpacked_files.select{|f| f.include?(".tex")}
      if texable_files.empty? && unpacked_files.length == 1
        new_new_dir = new_dir+"/"+unpacked_files.first.gsub(" ", "\\ ")
        unpacked_files = `ls #{new_dir}/#{unpacked_files.first.gsub(" ", "\\ ")}`.split("\n")
        new_dir = new_new_dir
        texable_files = unpacked_files.select{|f| f.include?(".tex")}
      end
      tmp_dir = "public/files/finished_#{random_name}"
      `mkdir -p #{tmp_dir}`
      texable_files.each do |tex_file|
        `rubber -d --into #{tmp_dir} #{new_dir}/#{tex_file}`
      end
      `zip -rj9 #{tmp_dir}.zip #{tmp_dir}`
      `rm -rf public/files/#{random_name}`
      `rm -rf public/files/#{random_name}.zip`
      `rm -rf public/files/finished_#{random_name}`
      send_file "#{tmp_dir}.zip", :filename => "#{filename}"
    end

    redirect '/'
  end
end
LatexConvert.run!