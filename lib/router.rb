require 'sinatra/base'
require 'digest/sha1'
require 'helpers'
require 'config'
require 'basic_auth'
require 'proxy'

class Kibana
  class Router < Sinatra::Base
    include Kibana::SharedLogger
    include Kibana::Proxy
    extend  Kibana::RouteHelpers

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

    def dashboard_namespace
      Digest::SHA1::hexdigest(session[:remote_user])
    end

    def pass_to_elasticsearch
      if Config[:elasticsearch].nil?
        logger.error "Proxy is disabled, set the :elasticsearch option"
        halt 502
      else
        proxy_pass Config[:elasticsearch]
      end
    end

    # == Routes
    get "/logout" do
      logger.debug("Logout triggered redirect to #{back}")
      session.clear
    end

    any "/kibana-int/*" do
      request.path_info.gsub!(%r`^/kibana-int`, "kibana-int_#{dashboard_namespace}")
      pass_to_elasticsearch
    end

    get "/*" do
      display_login!
      session[:namespace] ||= env['HTTP_REMOTE_USER']

      request.path_info = '/index.html' if request.path_info == '/'
      status, rackfile = catch(:halt) do
        send_file(::File.join(settings.kibana_root, request.path_info))
      end
      if request.path_info == '/index.html' && status == 200
        html = ''; rackfile.each {|i| html += i}
        [status, headers, mangle(html)]
      else
        if status == 404
          logger.error "Can't open file #{request.path_info}, check :kibana_root option (#{settings.kibana_root})"
        end
        [status, rackfile]
      end
    end

  end
end
