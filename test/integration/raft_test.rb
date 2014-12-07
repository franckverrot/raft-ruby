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

    uris.each_with_index do |uri, index|
      thread = Thread.new {
        other_nodes = uris.clone
        node_address = other_nodes.delete_at(index)
        logger = NodeLogger.new.tap do |l|
          l.color = colors[1 + index]
        end

        test_logger.log "Creating a new node #{node_address}, #{other_nodes}"
        DRb.start_service(uri, Node.new(node_address, other_nodes, logger))
      }
      thread.join
    end

    nodes||=[]
    nodes[0] = DRbObject.new_with_uri(uris[0])
    nodes[1] = DRbObject.new_with_uri(uris[1])
    nodes[2] = DRbObject.new_with_uri(uris[2])
    i = 0


    old_leader = nil

    loop do
      test_logger.log ""
      test_logger.log "*" * 20
      test_logger.log "#{i} BEGIN #{Time.now}"
      test_logger.log "*" * 20
      test_logger.log ""
      i+=1
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
            if node.status.include?("leader")
              old_leader = node
              node.mute
            end
          rescue Exception => e
            test_logger.log "[#{index}] I'm probably muted"
          end
        end
      end

      if i == 10
        test_logger.log "Reviving the old node"
        old_leader.unmute
      end
      test_logger.log "*" * 20
      test_logger.log " END "
      test_logger.log "*" * 20
      test_logger.log ""
    end
    DRb.thread.join
  end
end
