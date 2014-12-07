module Behaviors
  Follower = lambda do |node, follower_timeout|
    loop do
      sleep follower_timeout
      if node.follower?
        time = Time.now
        if time >= node.last_ping + follower_timeout
          begin
            node.following.status # ping-alike
            node.last_ping = Time.now
          rescue Exception => e
            node.log "Where's my master? :-( (#{node.following}) #{time >= node.last_ping + follower_timeout} (#{time} >= #{node.last_ping + 2})"
            node.becomes_candidate
          end
        else
          node.log "Master :#{node.following} (#{time}>=#{node.last_ping + follower_timeout})"
        end
      else
        # do nothing
      end
    end
  end
end
