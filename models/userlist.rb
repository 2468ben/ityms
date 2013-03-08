class UserList < Ohm::Model
  attribute :name, "main"
  list :users, :User
  
  def add_item(user)
    users.unshift(user) unless users.include?(user)
  end
  
  def get_page(page, pagelength=10)
    from = (page-1)*pagelength
    to = page*pagelength
    userlist = users.to_a[from..to]
  end
end
