require 'singleton'
require 'forwardable'

class Kibana
  class Config
    include Singleton

    attr_reader :load_error

    DEFAULT_SETTINGS = {
      :kibana_root  => 'kibana/src',
      :login_header => 'Kibana3 Login',
      :logging      => true,
      :log_level    => :info,
      :auth_method  => :basic,
      :auth_realm   => 'Restricted Area',
      :auth_file    => 'htpasswd',
      :session_domain => nil,
      :session_expire => 7200, # 2 hours
      :session_secret => 'change_me',
      :elasticsearch  => nil
    }

    def basedir
      @config_base ||= ::File.expand_path('..', File.dirname(__FILE__))
    end
    def path
      @config_path ||= ::File.join(basedir, 'config.rb')
    end

    def [](index)
      config[index]
    end

    # Forward public instance_methods of Kibana::Config
    class << self
      extend Forwardable
      args = Config.public_instance_methods(false).dup
      def_delegators(*args.unshift(:instance))
    end

    private

    def config
      @config ||= begin
        from_file = load_config.inject({}) {|h, kv| h[kv.first.to_sym] = kv.last; h}
        DEFAULT_SETTINGS.merge(from_file)
      end
    end

    def load_config
      # safely read config suppose it's supposed to be kind of hash
      content = ::File.open(path).read
      serialized = IO.popen(['ruby', '-e', Config::SAFE_HASH_EVAL]).read
      data = Marshal.load(serialized)
      data =  case data
              when Hash
                data
              else
                @load_error = data
                {}
              end
    end

    SAFE_HASH_EVAL=<<-EOS
      begin
        result = eval(File.open("#{path}").read).to_hash
      rescue Exception => e
        result = e
      ensure
        puts Marshal.dump(result)
      end
      EOS

  end
end
