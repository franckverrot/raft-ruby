module Behaviors
  Candidate = lambda do |node, candidate_timeout|
    loop do
      sleep candidate_timeout
      if node.candidate?
        #candidate_timeout = Random.new.rand * 2
        #sleep candidate_timeout
        # start campaign
        node.log "Entering election #{node.node_address}, term #{node.term}"
        #   1. tell other nodes we're candidate
        new_term = node.term + 1
        votes = node.nodes.map do |other_node|
          #   2. receive some answers
          begin
            other_node.vote_requested_by(node, new_term)
          rescue ::DRb::DRbConnError => e
            node.log "Node #{node} not available"
            [Node::No]
          rescue Exception => e
            node.log "Some node raised : #{e.message}"
            [Node::No]
          end
        end
        #     b. if quorum acquired, let's become the leader
        quorum = votes.reduce(0) { |t,i| t+= i[0] || 0 }
        if quorum >= node.required_quorum_to_be_elected
          node.log "My quorum is #{quorum}, i'll become the leader"
          # becoming the leader
          acknowledgements = node.nodes.map do |other_node|
            other_node.confirm_election_for(node)
          end
          #TODO what if no confirmation?
          node.term += 1
          node.becomes_leader
          node.log "Became the leader"
          break
        else
          node.log "Not becoming the leader, quorum = #{quorum} (required: #{node.required_quorum_to_be_elected})"

          # try to contact a renown leader
          votes.each do |vote|
            if vote[0] == Node::No && (proposed_node = vote[1])&& (term = vote[2])
              node.log "Got a proposal for #{proposed_node}, term #{term}"
              if proposed_node.leader?
                node.log "\tI'm gonna use this node"
                node.becomes_follower(proposed_node)
                node.term = proposed_node.term
                break
              else
                node.log "Y U NO PROPOSE LEADER"
                # meh
              end
            end
          end

          if node.following
            node.log "I'm finally following #{node.following}"
          else
            node.log "Couldn't find any interesting node"
          end
        end
      else
        #node.log "Status: #{@state}"
      end
    end
  end
end
