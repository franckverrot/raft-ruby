require 'test_helper'

class NodeTest < Minitest::Test
  def test_instantiate_one_leader_node
    this_node   = "druby://localhost:8787"
    node = ::Node.new(this_node)
    assert node.leader?, "A node without peers should be a leader"
  end

  def test_instantiate_one_candidate_node
    other_nodes = %w(druby://localhost:8788 druby://localhost:8789)
    this_node   = "druby://localhost:8787"
    node = ::Node.new(this_node, other_nodes)
    assert node.candidate?, "A node with peers should be a candidate"
  end
end
# The URI for the server to connect to

#i = 0
#
#old_leader = nil
#loop do
#  puts
#  print "*" * 20
#  print "#{i} BEGIN #{Time.now}"
#  print "*" * 20
#  puts
#  i+=1
#  sleep 1
#
#  nodes.each_with_index do |node, index|
#    begin
#      puts node.status
#    rescue Exception => e
#      puts "[#{index}] I'm probably muted"
#    end
#  end
#
#  if i == 4
#    puts "Killing the leader!"
#    nodes.each_with_index do |node, index|
#      begin
#        if node.status.include?("leader")
#          old_leader = node
#          node.mute
#        end
#      rescue Exception => e
#        puts "[#{index}] I'm probably muted"
#      end
#    end
#  end
#
#  if i == 10
#    puts "Reviving the old node"
#    old_leader.unmute
#  end
#  print "*" * 20
#  print " END "
#  print "*" * 20
#  puts
#end
#DRb.thread.join
