require 'singleton'
require 'logger'
require 'rack/nulllogger'
require 'config'

class Kibana
  module SharedLogger
    class Logger
      include Singleton
      attr_reader :logger

      def initialize
        if Config[:logging]
          @logger = ::Logger.new(STDERR)
          begin
            loglevel = eval('::Logger::' + Config[:log_level].to_s.upcase)
            @logger.level = loglevel
          rescue
            @logger.error("Unknown Log Level #{Config[:log_level]}, info is used")
          end
        else
          @logger = Rack::NullLogger.new(nil)
        end
      end
    end

    def self.logger
      Logger.instance.logger
    end

    def logger
      SharedLogger.logger
    end
  end
end
