$: << File.join(File.dirname(__FILE__), 'lib')
require 'router'

if self.is_a? Rack::Builder
  # inside rackup
  run Kibana::Router.new
else
  # direct invokation
  Kibana::Router.run!  
end
