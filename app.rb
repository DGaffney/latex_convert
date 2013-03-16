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
      dir = "public/files/#{random_name.gsub(".zip", "")}"
      `unzip public/files/#{random_name}.zip -d public/files/#{random_name}`
      unpacked_files = `ls #{dir}`.split("\n")-["__MACOSX"]
      texable_files = unpacked_files.select{|f| f.include?(".tex")}
      if texable_files.empty? && unpacked_files.length == 1
        new_dir = dir+"/"+unpacked_files.first.gsub(" ", "\\ ")
        unpacked_files = `ls #{dir}/#{unpacked_files.first.gsub(" ", "\\ ")}`.split("\n")
        dir = new_dir
        texable_files = unpacked_files.select{|f| f.include?(".tex")}
      end
      texable_files.each do |tex_file|
        tex_file_contents = File.read("#{dir}/#{tex_file}").gsub!(".eps}", "}")
        f = File.open("#{dir}/#{tex_file}", "w")
        f.write(tex_file_contents)
        f.close
        Dir.chdir(dir)
        binding.pry
        `pdflatex -shell-escape -interaction=nonstopmode #{tex_file}`
      end
      `zip -rj9 #{dir}.zip #{dir}`
      `rm -rf public/files/#{random_name}`
      `rm -rf public/files/#{random_name}.zip`
      `rm -rf public/files/finished_#{random_name}`
      send_file "#{tmp_dir}.zip", :filename => "#{filename}"
    end

    redirect '/'
  end
end
LatexConvert.run!