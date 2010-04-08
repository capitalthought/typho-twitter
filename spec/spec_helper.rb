$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'typho-twitter'
require 'spec'
require 'spec/autorun'

module SpecLogger
  def log message
    puts message.to_s + "<br/>"
  end
end

Spec::Runner.configure do |config|
  
end
