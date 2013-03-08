module PostUtils
  def link_to_user(user, currentuser)
    username = user.username;
    displayname = user == currentuser ? "Me" : username;
    f = <<-HTML
<a href="/#{user.username}">#{displayname}</a>
    HTML
  end
  
  def pluralize(singular, plural, count)
    if count == 1
      count.to_s + " " + singular
    else
      count.to_s + " " + plural
    end
  end
  
  def time_with_timezone(time)
    time + $timezoneoffset
  end
  
  def timestamp(time)
    time_ago_in_words(time_with_timezone(time))
  end
  
  def time_ago_in_words(time)
    distance_in_minutes = ((Time.now.utc - time)/60).round
    case distance_in_minutes
    when 0..1439
      return time.strftime("%-l:%M%P")
    else
      return time.strftime("%b %-d %Y")
    end
  end
  
end