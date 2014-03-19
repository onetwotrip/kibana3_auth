require 'sinatra/base'
require 'tempfile'
require 'htauth'
require 'digest/md5'
require 'config'
require 'helpers'

class Kibana
  class BasicAuth < Sinatra::Base
    include SharedLogger
    use Rack::Session::Cookie,  :key => 'rack.session',
                                :path => '/',
                                :domain => Config[:session_domain],
                                :expire_after => Config[:session_expire],
                                :secret => Config[:session_secret]

    set :protection, :except => [:json_csrf, :http_origin]

    def protected!
      authenticate! unless auth.provided?
      halt 400, "Basic Authentication is required\n" unless auth.basic?
      halt 403, "Forbidden\n" unless authenticated?
    end

    def auth
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
    end

    def authenticate!
      headers['WWW-Authenticate'] = %Q(Basic realm="#{Config[:auth_realm]}")
      halt 401, "Not authorized\n"
    end

    def authenticated?
      user, pass = auth.credentials
      entry = htauth_file.fetch(user)
      result = entry && entry.authenticated?(pass)
      logger.error "Authentication failed client: #{request.ip}, user: #{user}" unless result
      result
    end

    post '/auth' do
      session[:authenticated] = false
      protected!
      session[:authenticated] = true
      session[:remote_user]   = auth.credentials.first
      logger.debug "/auth referrer to redirect back is #{back}"
      if back.to_s.empty?
        [200, "authorized\n"]
      else
        redirect back, 301
      end
    end

    private

    def htauth_file
      # read file if it's been updated or never read
      csum = ::Digest::MD5.file(Config[:auth_file]).digest
      if @htauth_csum.nil? || csum != @htauth_csum
        @htauth_file = HTAuth::PasswdFile.open(Config[:auth_file])
        @htauth_csum = csum
      end
      @htauth_file
    rescue *[SystemCallError, HTAuth::FileAccessError]
      logger.error "htauth_file can not be read: #{::File.expand_path(Config[:auth_file])}"
      tmp = Tempfile.new('kibana_htauth_')
      htauth = HTAuth::PasswdFile.open(tmp.path)
      htauth.load_entries
      tmp.close and tmp.unlink
      @htauth_file = htauth
    end

  end
end
