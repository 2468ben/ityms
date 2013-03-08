require 'redis'
rack_env = ENV["RACK_ENV"]
if rack_env == 'production' 
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Ohm.connect(:host => uri.host, :port => uri.port, :password => uri.password)
else
  $redis = Ohm.connect
end

require_relative 'user'
require_relative 'post'
require_relative 'postlist'
require_relative 'userlist'
require_relative 'usertimeline'
require_relative 'maintimeline'

$maintimeline = MainTimeline.all.first || MainTimeline.create 
$userlist = UserList.all.first || UserList.create