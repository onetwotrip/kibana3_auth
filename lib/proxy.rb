require 'net/http'
require 'timeout'
require 'config'
require 'helpers'

class Kibana
  module Proxy
    include SharedLogger

    def proxy_pass(url)
      uri = to_uri(url)
      res = Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') do |http|
        m = request.request_method
        case m
        when "GET", "HEAD", "DELETE", "OPTIONS"
          req = Net::HTTP.const_get(m.capitalize).new(request.fullpath)
          request_headers.each {|kv| req[kv.first] = kv.last}
        when "PUT", "POST"
          req = Net::HTTP.const_get(m.capitalize).new(request.fullpath)
          req.body = request.body.read
          request_headers.each {|kv| req[kv.first] = kv.last}
        else
          logger.error("HTTP method #{m} is not supported")
          halt 405
        end
        http.request(req)
      end
      halt res.code.to_i, res.to_hash, [res.body]
    rescue SystemCallError
      halt 503
    rescue Timeout::Error
      halt 504
    end

    def to_uri(url)
      url = url.to_s
      url = "http://#{url}" if not url.start_with?('http')
      URI(url)
    end

    def request_headers
      env.inject({}) {|h, kv| kv.first =~ /HTTP_(.*)/ and h[$1] = kv.last; h}
    end

  end
end
