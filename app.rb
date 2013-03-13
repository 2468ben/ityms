require 'sinatra/base'
require 'erb'
require 'ohm'
require 'mail'
require 'cgi'
require 'uri'
require 'differ'
require 'base64'
require 'json'
require 'dalli'
require 'rack-cache'
require 'sinatra/assetpack'

require_relative 'helpers/tzinfo_timezone'

class ItymsApp < Sinatra::Application
  set :root, File.dirname(__FILE__)
  register Sinatra::AssetPack
  set :sessions, true
  set :protection, :except => [:remote_token, :json_csrf]
  APP_CONFIG = YAML.load_file("config/environment.yml")['production']
  configure :production do
    $testing = false
    set :raise_errors, false
    set :show_exceptions, false
    require 'newrelic_rpm'
    set :cache, Dalli::Client.new
    Mail.defaults do
    	delivery_method :smtp, {	
    		:address => 'smtp.sendgrid.net',
    		:port => 587,
    		:domain => 'heroku.com',
    		:user_name => ENV['SENDGRID_USERNAME'],
    		:password => ENV['SENDGRID_PASSWORD'],
    		:authentication => 'plain',
    		:enable_starttls_auto => true }
    end
  end
  configure :development do
    require 'better_errors'
    use BetterErrors::Middleware
    BetterErrors.application_root = File.expand_path("..", __FILE__)
    $testing = true
    Mail.defaults do
    	delivery_method :smtp, {	
    		:address => 'smtp.gmail.com',
    		:port => 587,
    		:domain => 'gmail.com',
    		:user_name => ENV['SENDGRID_USERNAME'],
    		:password => ENV['SENDGRID_PASSWORD'],
    		:authentication => 'plain',
    		:enable_starttls_auto => true }
    end
  end
  
  assets {
    js :validate, ['js/validate.min.js']

    css :application, [
        'css/base.css',
        'css/layout.css',
        'css/skeleton.css',
        'css/custom.css'
    ]

    js_compression :jsmin
    css_compression :simple
  }

  $mail_username = ENV['SENDGRID_USERNAME']
  $top_domain = APP_CONFIG['top_domain']
  
  $timezone_set = false
  $timezoneoffset = TzinfoTimezone.new("Eastern Time (US & Canada)").dst_utc_offset
  Differ.format = :html
  
  $plugin_link = "https://chrome.google.com/webstore/detail/ityms/dmfehapjdpdelmpikcbdicfmolflpckg"
  
  before do
     #cache_control :public, max_age: 60
    if (@logged_in_user = User[session["user_id"]] and @logged_in_user.activated == "true")
      unless $timezone_set
        $timezone_set = true
        $timezoneoffset = TzinfoTimezone.new(@logged_in_user.timezone).dst_utc_offset
      end
      if %w(/admin).include?(request.path_info) and
        @logged_in_user.permission_level != "admin"
        goto_login "You don't have the permission to access that page."
      end
    else
      unless %w(/login /signup /resetpassword /getactivationlink /unactivated /about /terms /privacy /contact /changedpassword).include?(request.path_info) or
        request.path_info =~ /\.(css|js|png|ico)$/ or request.path_info =~ /(activate|api|changepassword)/ or request.path_info == '/'
        redirect '/login', 303
      end
    end
  end
  helpers do
  end
end

require_relative 'helpers/init'
require_relative 'routes/init'
require_relative 'models/init'
