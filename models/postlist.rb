class PostList < Ohm::Model
  list :posts, :Post
  
  def add_item(post)
    posts.unshift(post) unless posts.include?(post)
  end
  
  def delete_item(post)
    posts.delete(post) if posts.include?(post)
  end
  
  def delete_user_items(user)
    posts.each do |post|
      posts.delete(post) if post.user == user
    end
  end
  
  def get_page(page, pagelength=10)
    from = (page-1)*pagelength
    to = page*pagelength
    pageitems = posts.to_a[from..to]
  end
end
