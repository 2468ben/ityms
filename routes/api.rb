class ItymsApp < Sinatra::Application
  get '/api/get_token' do
    result = {}
    if user = user_activated(params, false)
      user.new_apitoken if user.api_token_expiry.to_i < Time.now.to_i
      result[:token] = user.api_token
      result[:expiry] = user.api_token_expiry
    end
    content_type :json
    result.to_json
  end
  post '/api/add_post' do
    result = { :success => false}
    if user = user_activated(params)
      success = make_post(user, params)
      result[:success] = true if success
    end
    content_type :json
    result.to_json
  end
  get '/api/url_posts' do
    result = {:posts => []}
    if user = user_activated(params)
      posts = Post.find(:url => params[:url]).sort_by(:likecount, :order => "DESC", :limit => [0, 10]).to_a
      posts.each do |post|
        result[:posts] = [] unless result[:posts]
        result[:posts].push({
          :id => post.id,
          :phrase_diff => post.phrase_diff,
          :likecount => post.likecount
        })
      end
    end
    content_type :json
    result.to_json
  end
  def user_activated(params, check_pw = true)
    if user = User.find(:email => params[:email]).first and user.activated
      success = (!check_pw or Base64.decode64(params[:api_token]) == user.api_token)
    end
    return success ? user : nil
  end
end