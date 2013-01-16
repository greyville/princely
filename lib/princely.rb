# PrinceXML Ruby interface. 
# http://www.princexml.com
#
# Library by Subimage Interactive - http://www.subimage.com
#
#
# USAGE
# -----------------------------------------------------------------------------
#   princely = Princely.new()
#   html_string = render_to_string(:template => 'some_document')
#   send_data(
#     princely.pdf_from_string(html_string),
#     :filename => 'some_document.pdf'
#     :type => 'application/pdf'
#   )
#
$:.unshift(File.dirname(__FILE__))
require 'logger'
require 'princely/rails' if defined?(Rails)

class Princely
  attr_accessor :exe_path, :style_sheets, :log_file, :logger

  # Initialize method
  #
  def initialize(options={})
    # Finds where the application lives, so we can call it.
    @exe_path = options[:path] || find_prince_executable
    raise "Cannot find prince command-line app in $PATH" if @exe_path.length == 0
    raise "Cannot find prince command-line app at #{@exe_path}" if @exe_path && !File.executable?(@exe_path)
    @style_sheets = ''
    @log_file = options[:log_file]
    @logger = options[:logger]
  end

  def logger
    @logger ||= defined?(Rails) ? Rails.logger : StdoutLogger
  end

  def log_file
    @log_file ||= defined?(Rails) ? 
            Rails.root.join("log/prince.log") :
            File.expand_path(File.dirname(__FILE__) + "/log/prince.log")
  end

  def ruby_platform
    RUBY_PLATFORM
  end

  def find_prince_executable
    if ruby_platform =~ /mswin32/
      "C:/Program Files/Prince/Engine/bin/prince"
    else
      `which prince`.chomp
    end
  end
  
  # Sets stylesheets...
  # Can pass in multiple paths for css files.
  #
  def add_style_sheets(*sheets)
    for sheet in sheets do
      @style_sheets << " -s #{sheet} "
    end
  end
  
  # Returns fully formed executable path with any command line switches
  # we've set based on our variables.
  #
  def exe_path
    # Add any standard cmd line arguments we need to pass
    @exe_path << " --input=html --server --log=#{log_file} "
    @exe_path << @style_sheets
    return @exe_path
  end
  
  # Makes a pdf from a passed in string.
  #
  # Returns PDF as a stream, so we can use send_data to shoot
  # it down the pipe using Rails.
  #
  def pdf_from_string(string, output_file = '-')
    path = self.exe_path()
    # Don't spew errors to the standard out...and set up to take IO 
    # as input and output
    path << ' --silent - -o -'
    
    # Show the command used...
    logger.info "\n\nPRINCE XML PDF COMMAND"
    logger.info path
    logger.info ''
    
    # Actually call the prince command, and pass the entire data stream back.
    pdf = IO.popen(path, "w+")
    pdf.puts(string)
    pdf.close_write
    result = pdf.gets(nil)
    pdf.close_read
    result.force_encoding('BINARY') if RUBY_VERSION >= "1.9"
    return result
  end

  def pdf_from_string_to_file(string, output_file)
    path = self.exe_path()
    # Don't spew errors to the standard out...and set up to take IO 
    # as input and output
    path << " --silent - -o '#{output_file}' >> '#{log_file}' 2>> '#{log_file}'"
    
    # Show the command used...
    logger.info "\n\nPRINCE XML PDF COMMAND"
    logger.info path
    logger.info ''
    
    # Actually call the prince command, and pass the entire data stream back.
    pdf = IO.popen(path, "w+")
    pdf.puts(string)
    pdf.close
  end

  class StdoutLogger
    def self.info(msg)
      puts msg
    end
  end
end
