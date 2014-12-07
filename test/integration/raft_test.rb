require 'test_helper'

class RaftIntegrationtest < Minitest::Test
  def xtest_all

    # The URI for the server to connect to
    uris=%w(
  druby://localhost:8787
  druby://localhost:8788
  druby://localhost:8789
    )

    test_logger = NodeLogger.new.tap do |l|
      l.level = NodeLogger::INFO
    end

    colors = [:white, :red, :green, :magenta]

    nodes = uris.map.with_index do |uri, index|
      other_nodes = uris.clone
      node_address = other_nodes.delete_at(index)
      logger = NodeLogger.new.tap do |l|
        l.color = colors[1 + index]
      end

      test_logger.log "Creating a new node #{node_address}, #{other_nodes}"
      Node.new(node_address, other_nodes, logger)
    end

    nodes.each { |node| node.start }

    old_leader = nil

    i = -1
    loop do
      i+=1

      test_logger.log "#{'*' * 20 } #{i} BEGIN #{Time.now} #{'*' * 20 }"
      sleep 1

      nodes.each_with_index do |node, index|
        begin
          test_logger.log node.status
        rescue Exception => e
          test_logger.log "[#{index}] I'm probably muted"
        end
      end

      if i == 4
        test_logger.log "Killing the leader!"
        nodes.each_with_index do |node, index|
          begin
            if node.leader?
              test_logger.log "Killing node #{node}"
              old_leader = node
              node.mute
            end
          rescue Exception => e
            test_logger.log "[#{index}] I'm probably muted"
          end
        end
      end

      if i == 15
        test_logger.log "Reviving the old node"
        old_leader.unmute
      end
      test_logger.log "#{'*' * 20 } END #{'*' * 20 }\n"
    end
  end
end
