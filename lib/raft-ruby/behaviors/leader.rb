module Behaviors
  Leader = lambda do |node, leader_timeout|
    loop do
      sleep leader_timeout
      if node.leader? && !node.muted
        leader_timeout = Random.new.rand  / 2
        all_there = node.nodes.map do |node|
          node.still_connected?
        end.all? { |e| e }

        if all_there
          # do nothing
        else
          node.becomes_candidate
        end
      end
    end
  end
end
