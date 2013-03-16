require 'rubygems' if RUBY_VERSION < "1.9"
require 'sinatra/base'
require 'erb'
require 'pry'
PREAMBLE_FOR_GRAPHICS = "\\newif\\ifpdf
\\ifx\\pdfoutput\\undefined
   \\pdffalse
\\else
   \\pdfoutput=1
   \\pdftrue
\\fi
\\ifpdf
   \\usepackage{graphicx}
   \\usepackage{epstopdf}
   \\DeclareGraphicsRule{.eps}{pdf}{.pdf}{`epstopdf #1}
   \\pdfcompresslevel=9
\\else
   \\usepackage{graphicx}
\\fi"
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
      pwd = `pwd`.split("\n").first
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
      binding.pry
      texable_files.each do |tex_file|
        tex_file_contents = File.read("#{dir}/#{tex_file}")
        tex_file_contents.gsub!(".eps}", "}")
        tex_file_contents.gsub!(/(\\documentclass.*)/, "\r\n#{$1}#{PREAMBLE_FOR_GRAPHICS}\r\n") if !tex_file_contents.scan(/(\\documentclass.*)/).empty?
        f = File.open("#{dir}/#{tex_file}", "w")
        f.write(tex_file_contents)
        f.close
        Dir.chdir(dir)
        puts "pdflatex -shell-escape -interaction=nonstopmode #{tex_file}"
        `pdflatex -shell-escape -interaction=nonstopmode #{tex_file}`
      end
      Dir.chdir(pwd)
      `zip -rj9 #{dir}.zip #{dir}`
      # `rm -rf #{dir}`
      redirect "#{dir}.zip".gsub("public/", "")
    end

    redirect '/'
  end
  
end
LatexConvert.run!