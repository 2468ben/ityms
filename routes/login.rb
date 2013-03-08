class ItymsApp < Sinatra::Application
  get '/login/activated/:email' do |email|
    redirect "/login?email=#{email}"
  end
  get '/login' do
    params[:email] = CGI.unescapeHTML(params[:email]) if params[:email]
    if session[:login_flash]
      @login_error = session[:login_flash]
      session[:login_flash] = nil
    end
    erb :login
  end
  post '/signup' do
    begin
      user = User.new(
        :email => params[:email],
        :username => params[:username],
        :postlist => PostList.create, 
        :usertimeline => UserTimeline.create,
        :created_at => Time.now.to_s,
        :permission_level => "admin",
        :timezone => "Eastern Time (US & Canada)"
      )
      if user.valid?
        if $testing
          user.save
          $timezoneoffset = TzinfoTimezone.new("Eastern Time (US & Canada)").dst_utc_offset
          user.save_password params[:password]
          activate_user user
        end
        initialize_user user, params[:password]
      else
        signup_errors = Array.new()
        user.errors.each {|k, v| signup_errors.push describe_error(k,v)}
        @signup_error = signup_errors.join("<br />")
      end
    rescue Ohm::UniqueIndexViolation
      if !User.find(:email => params[:email]).empty?
        @signup_error = "That email is already in use."
      elsif !User.find(:username => params[:username]).empty?
        @signup_error = "That username is already taken."
      end
    end
    if @signup_error
      erb :login
    elsif $testing
      redirect "/"
    else
      redirect "/unactivated"
    end
  end

  def initialize_user(user, password)
    user.save
    user.save_password password
    user.deactivate
    user.make_reset_token
    send_activation_email user 
  end

  def send_activation_email(user)
    send_email user.email, "Activate your account", activation_body(user, "text"), activation_body(user, "html")
  end
  def activation_body(user, type="text")
    user_url = "#{user.id}/#{user.temp_token}"
    link_url = "#{$top_domain}/activate/#{user_url}"
    "Dear human,\n\nSomeone just signed up on our site with your email address. Was that you? We hope so.\n"\
    "If it was you, then great! Click this link to confirm our hunch and prove you're not some malicious robot.\n"\
    "#{type == 'html' ? '<a href='+link_url+'>'+link_url+'</a>' : link_url}\n\n"\
    "If it wasn't you, then ignore this email and you won't hear from us again.\n\n"\
    "Sincerely,\nITYMS"
  end
  def send_passwordreset_email(user)
    send_email user.email, "Reset your password", passwordreset_body(user, "text"), passwordreset_body(user, "html")
  end
  def passwordreset_body(user, type="text")
    user_url = "#{user.id}/#{user.temp_token}"
    link_url = "#{$top_domain}/changepassword/#{user_url}"
    body = "Dear human,\n\nSomeone just asked to reset your password on our site. Was that you? We hope so.\n"\
    "If it was you, then great! Click this link to change your password.\n"\
    "#{type == 'html' ? '<a href='+link_url+'>'+link_url+'</a>' : link_url}\n\n"\
    "If it wasn't you, then ignore this email and you won't hear from us again.\n\n"\
    "Sincerely,\nITYMS"
  end
  
  def send_email(to, subject, text_body, html_body)
  	mail = Mail.deliver do
  		to to
  		from "ITYMS <#{$mail_username}>"
      subject subject
  		text_part do
  			body text_body
  		end
      html_part do
        content_type 'text/html; charset=UTF-8'
        body html_body
      end
  	end
  end

  get "/unactivated" do
    "We have trust issues, so we sent a confirmation link to your email. Click on that link to finish this horrible signup process.<br /><br /><br /><br /><br /><br /><br /><br />THIS SENTENCE IS A DISTRACTION"
  end

  get "/activate/:userid/:activation_token" do |userid, activation_token|
    if user = User[userid] and user.temp_token == activation_token 
      if user.activated == "false"
        activate_user user
      else
        goto_login "You're already activated! Log in!"
      end
    else
       goto_login "We couldn't find a user with that token, sorry."
    end
  end

  get "/changepassword/:userid/:change_token" do |userid, change_token|
    if change_token == "logged_in" and @logged_in_user == User[userid] and @logged_in_user.activated == "true"
      session[:changepasswordcreds] = {
        :id => userid,
        :token => @logged_in_user.random_string(30)
      }
      erb :changepassword
    elsif user = User[userid] and user.temp_token == change_token and @logged_in_user.activated == "true"
      session[:changepasswordcreds] = {
        :id => userid,
        :token => change_token
      }
      erb :changepassword
    else
      goto_login "We couldn't find a user with that token, sorry."
    end
  end
  
  post '/changepassword' do
    if check1 = params[:token] and check2 = session[:changepasswordcreds] and check1 == check2[:token]
      user = User[check2[:id]]
      new_password = params[:password]
      user.changed_password(new_password)
      goto_login "Password changed! Log in! Please!"
    else
      goto_login "Something went wrong. It's probably your fault so try again."
    end
  end

  def activate_user(user)
    user.activate
    $userlist.add_item(user)
    redirect "/login/activated/#{CGI.escapeHTML(user.email)}"
  end

  def describe_error(key, value)
    return "#{key} #{value[0]}"
  end

  get '/logout' do
    session["user_id"] = nil
    goto_login   
  end
  
  get '/getactivationlink' do
    erb :getactivationlink
  end
  
  post '/getactivationlink' do
    if user = User.find(:email => params[:email]).first
      if user.activated == "false"
        user.make_reset_token
        send_activation_email(user)
        redirect '/unactivated'
      else
        goto_login "You're already activated!"
      end
    else
      goto_login "Sorry, we can't find anyone with that email. Try again."
    end
  end

  def goto_login(message = nil)
    session[:login_flash] = message if message
    redirect "/login"
  end
  
  get '/resetpassword' do
    erb :resetpassword
  end
  
  post '/resetpassword' do
    if user = User.find(:email => params[:email]).first
      if user.activated == "false"
        goto_login "User not activated yet. Click the link in your email or get a new confirmation link below."
      else
        user.make_reset_token
        send_passwordreset_email user
        return "We forgive you, so we sent a reset link to your email. Click on that link to pick a new password.<br /><br /><br /><br /><br /><br /><br /><br />THIS SPACE INTENTIONALLY LEFT BLANK"
      end
    else
      goto_login "Sorry, we can't find anyone with that email. Try again."
    end
  end
  
  post '/login' do
    if user = User.find(:email => params[:email]).first and user.hash_pw(user.salt, params[:password]) == user.hashed_password
      if user.activated == "false"
        goto_login "User not activated yet. Click the link in your email or get a new confirmation link below."
      else
        session["user_id"] = user.id
        redirect '/'
      end
    else
      @login_error = "Incorrect email or password"
      erb :login
    end
  end
end