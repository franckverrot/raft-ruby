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
#      puts node.status
#    rescue Exception => e
#      puts "[#{index}] I'm probably muted"
#    puts "Reviving the old node"
#    old_leader.unmute
