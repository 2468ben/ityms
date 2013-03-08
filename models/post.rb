class Post < Ohm::Model
  attribute :phrase_diff
  attribute :created_at
  attribute :domain
  index :domain
  attribute :url
  index :url
  attribute :activated
  attribute :likecount
  set :likingUsers, :User
  reference :user, :User
end