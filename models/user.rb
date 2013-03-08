class User < Ohm::Model
  attribute :email
  unique :email
  index :email
  attribute :username
  unique :username
  index :username
  attribute :permission_level
  attribute :timezone
  attribute :salt
  attribute :hashed_password
  attribute :temp_token
  attribute :api_token
  attribute :api_token_expiry
  attribute :created_at
  attribute :activated
  reference :postlist, :PostList
  reference :usertimeline, :UserTimeline
  collection :posts, :Post
  set :likedPosts, :Post
  set :followers, :User
  set :followees, :User
  
  def validate
    assert_present :email
    assert_email :email
    assert_present :username
    assert_format :username, /^\w+$/
    assert_length :username, 5..20
  end

  def publish_post(post)
    postlist.add_item(post)
    followers.each do |follower|
      follower.usertimeline.add_item(post)
    end
    post
  end
  
  def activate()
    update(:activated => true, :temp_token => nil)
  end
  
  def deactivate()
    update(:activated => false)
  end
  
  def changed_password(password)
    save_password(password)
    update(:temp_token => nil)
  end
  
  def save_password(password)
    newsalt = new_salt
    update(:hashed_password => hash_pw(newsalt, password), :salt => newsalt)
    new_apitoken
  end
  
  def new_apitoken
    update(:api_token => random_string(33), :api_token_expiry => (Time.now + 3600).to_i)
  end
  
  def new_salt
    random_string(6)
  end
  
  def hash_pw(salt, password)
    Digest::SHA1.hexdigest(salt + password)
  end
  
  def random_string(len)
    #generate a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end
  
  def make_reset_token
      update(:temp_token => random_string(30))
  end
  
  def posts(page=1)
    postlist.get_page(page)
  end
  
  def timeline(page=1)
    usertimeline.get_page(page)
  end

  def follow(user)
    return if user == self
    followees.add(user) unless followees.include?(user)
    user.followers.add(self) unless user.followers.include?(self)
  end
  
  def stop_following(user)
    followees.delete(user) if followees.include?(user)
    user.followers.delete(self) if user.followers.include?(self)
  end
  
  def following?(user)
    followees.include?(user)
  end
end