class ItymsApp < Sinatra::Application
  get '/' do
    if @logged_in_user and @logged_in_user = User[session["user_id"]] and @logged_in_user.activated == "true"
      @posts = @logged_in_user.usertimeline.get_page(1)
      @followers = @logged_in_user.followers.to_a
      @followees = @logged_in_user.followees.to_a
      erb :index
    else
      @posts = $maintimeline.get_page(1)
      erb :splash
    end
  end
  get '/privacy' do
    erb :privacy
  end
  get '/terms' do
    erb :terms
  end
  get '/contact' do
    erb :contact
  end
  get '/about' do
    @posts = $maintimeline.get_page(1)
    erb :splash
  end
  get '/timeline' do
    @posts = $maintimeline.get_page(1)
    erb :timeline
  end
  get '/post/new' do
    erb :newpost
  end
  post '/post' do
    success = make_post(@logged_in_user, params)
    if success
      redirect '/'
    end
    if @posting_error
      @posts = @logged_in_user.postlist.get_page(1)
      erb :index
    end
  end
  
  def make_post(user, params)
    puts "MAKING POST"
    success = false
    if (params[:url] =~ URI::ABS_URI).nil?
      @posting_error = "Not a valid URL."
    else
      phrase_diff = parse_phrases(params[:new_phrase], params[:old_phrase])
      domain = URI.parse(params[:url]).host
      post = Post.new(
        :user => user,
        :url => params[:url],
        :domain => domain,
        :phrase_diff => phrase_diff,
        :created_at => Time.now.utc.to_s,
        :activated => true,
        :likecount => "0"
      )
      if post.valid?
        post.save
        user.publish_post(post)
        $maintimeline.add_item(post)
        success = true
      else
        @posting_error = "The post couldn't be saved. Try again."
      end
    end
    success
  end
  def clean_text(text)
    text.gsub!(/(^\s+|\s+$|<[^\>]*>|javascript:|[^\w\s\'\"\.\,\;\:\-\?\!\@\#\$\%\(\)\/])/i,"")
  end
  def parse_phrases(new_phrase, old_phrase)
    clean_text(old_phrase)
    clean_text(new_phrase)
    Differ.diff_by_word(new_phrase, old_phrase)
  end
  
  get '/popular' do
    @posts = toptenposts(Post.all)
    erb :timeline
  end
  
  def toptenposts(posts)
    posts.sort_by(:likecount, :limit => [0, 10], :order => "DESC")
  end
  
  get '/settings' do
    @defaulttimezone = TzinfoTimezone.new(@logged_in_user.timezone).to_s
    @timezones = TzinfoTimezone.all
    @settings_error = "Timezone changed." if params[:timezone_changed] == "true"
    erb :settings
  end
  post '/actually_deactivate_account' do
    if @logged_in_user.hash_pw(@logged_in_user.salt, params[:password]) == @logged_in_user.hashed_password
      deactivate_user(@logged_in_user)
      session["user_id"] = nil
      goto_login "User #{@logged_in_user.username} deactivated. And stay out!"
    else
      @deactivate_error = "Incorrect password"
      redirect '/deactivate_account'
    end
  end
  get '/deactivate_account' do
    erb :deactivateaccount
  end
  
  def deactivate_user(user)
    user.posts.each do |post|
      post.update(:activated => "false")
      post.likingUsers.each do |user|
        user.likedPosts.delete(post)
      end
      post.update(:likecount => 0)
    end
    user.likedPosts.each do |post|
      post.likingUsers.delete(user)
      post.update(:likecount => (post.likecount.to_i - 1).to_s)
    end
    user.followers.each do |follower|
      follower.stop_following(user)
      follower.usertimeline.delete_user_items(user)
    end
    user.followees.each do |followee|
      user.stop_following(followee)
    end
    user.deactivate
    $userlist.users.delete(user)
    $maintimeline.delete_user_items(user)
  end
  
  post '/change_timezone' do
    timezone_string = params[:timezone].split(" ")[1..-1].join(" ")
    @logged_in_user.update(:timezone => timezone_string)
    $timezoneoffset = TzinfoTimezone.new(timezone_string).dst_utc_offset
    redirect '/settings?timezone_changed=true'
  end

  get '/:follower/follow/:followee' do |follower_username, followee_username|
    follower = User.find(:username => follower_username).first
    followee = User.find(:username => followee_username).first
    if @logged_in_user == follower
      follower.follow(followee)
      redirect "/" + followee_username
    else
      redirect '/'
    end
  end

  get '/:follower/stopfollow/:followee' do |follower_username, followee_username|
    follower = User.find(:username => follower_username).first
    followee = User.find(:username => followee_username).first
    if @logged_in_user == follower
      follower.stop_following(followee)
      redirect "/" + followee_username
    else
      redirect '/'
    end
  end
  get '/admin' do
    "HELLO ADMIN!"
  end
  get '/:username' do |username|
    if @user = User.find(:username => username).first and @user.activated == "true"
      @posts = @user.postlist.get_page(1)
      @followers = @user.followers.to_a
      @followees = @user.followees.to_a
      erb :profile
    else
      "Sorry, no user found with that username. Maybe they deleted their account?"
    end
  end
  
  get '/post/delete/:postid' do |postid|
    if post = Post[postid] and post.user == @logged_in_user
      post.likingUsers.each do |user|
        user.likedPosts.delete(post)
      end
      @logged_in_user.postlist.delete_item(post)
      @logged_in_user.followers.each do |follower|
        follower.usertimeline.delete_item(post)
      end
      $maintimeline.delete_item(post)
      post.delete
    end
    redirect "/#{@logged_in_user.username}"
  end
  
  get '/post/like/:postid' do |postid|
    if post = Post[postid]
      post.likingUsers.add(@logged_in_user) if !post.likingUsers.include?(@logged_in_user)
      @logged_in_user.likedPosts.add(post) if !@logged_in_user.likedPosts.include?(post)
      post.update(:likecount => (post.likecount.to_i + 1).to_s)
    end
    redirect "/#{post.user.username}"
  end
  get '/post/unlike/:postid' do |postid|
    if post = Post[postid] and post.likingUsers.include?(@logged_in_user)
      post.likingUsers.delete(@logged_in_user) if post.likingUsers.include?(@logged_in_user)
      @logged_in_user.likedPosts.delete(post) if @logged_in_user.likedPosts.include?(post)
      post.update(:likecount => (post.likecount.to_i - 1).to_s)      
    end
    redirect "/#{post.user.username}"
  end
  get '/post/:postid' do |postid|
    if post = Post[postid]
      erb :postdetails, :locals => {:post => post }
      #show the post in detail FUN STUFF
    end
  end
end