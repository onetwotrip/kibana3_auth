require 'sinatra/base'
require 'helpers'
require 'config'
require 'basic_auth'

class Kibana
  class Router < Sinatra::Base
    include SharedLogger

    # if configuration parsing has failed
    logger = SharedLogger.logger
    load_error = Config.load_error
    if not load_error.nil?
      logger.error "Configuration file must return Hash"
      logger.error load_error.message
      exit(1)
    end

    # include authentication middleware
    begin
      AUTH_MWARE = eval(Config[:auth_method].to_s.downcase.capitalize + 'Auth')
      use AUTH_MWARE
    rescue
      logger.error "Authentication method #{Config[:auth_method]} is not supported"
      exit(1)
    end

    # pasthrough all config options as settings
    configure do
      set :bind, '0.0.0.0'
      set :port, 9292
      Config::DEFAULT_SETTINGS.keys.each do |k|
        set k, Config[k]
      end
    end

    def display_login!
      unless session[:authenticated]
        logger.debug "Session not found, need authentication"
        halt 200, erb(:login)
      end
    end

    get "/logout" do
      logger.debug("Logout triggered redirect to #{back}")
      session[:authenticated] = false
    end

    get "/*" do
      display_login!
      request.path_info = '/index.html' if request.path_info == '/'
      status, rackfile = catch(:halt) do
        send_file(::File.join(settings.kibana_root, request.path_info))
      end
      if request.path_info == '/index.html'
        html = ''; rackfile.each {|i| html += i}
        [status, headers, mangle(html)]
      else
        [status, rackfile]
      end
    end

    # insert logout header and script into html
    def mangle(html)
      html   = html.dup
      header = erb :logout_header
      logout = erb :logout_js
      html.gsub!(/(<body.*?>)/, "\\1\n#{header}")
      html.gsub!(/(<head.*?>)/, "\\1\n#{logout}")
      headers['Content-Length'] = html.bytesize.to_s
      html
    end

  end
end
