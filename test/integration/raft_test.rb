require 'test_helper'

class RaftIntegrationtest < Minitest::Test
  def xtest_all

    # The URI for the server to connect to
    uris=%w(
  druby://localhost:8787
  druby://localhost:8788
  druby://localhost:8789
    )

    uris.each_with_index do |uri, index|
      thread = Thread.new {
        other_nodes = uris.clone
        node_address = other_nodes.delete_at(index)
        puts "Creating a new node #{node_address}, #{other_nodes}"
        DRb.start_service(uri, Node.new(node_address, other_nodes))
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
      puts
      print "*" * 20
      print "#{i} BEGIN #{Time.now}"
      print "*" * 20
      puts
      i+=1
      sleep 1

      nodes.each_with_index do |node, index|
        begin
          puts node.status
        rescue Exception => e
          puts "[#{index}] I'm probably muted"
        end
      end

      if i == 4
        puts "Killing the leader!"
        nodes.each_with_index do |node, index|
          begin
            if node.status.include?("leader")
              old_leader = node
              node.mute
            end
          rescue Exception => e
            puts "[#{index}] I'm probably muted"
          end
        end
      end

      if i == 10
        puts "Reviving the old node"
        old_leader.unmute
      end
      print "*" * 20
      print " END "
      print "*" * 20
      puts
    end
    DRb.thread.join
  end
end
