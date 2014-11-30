class Node
  def initialize(node_address, other_nodes = [])
    @muted = false
    @node_address = node_address
    @term  = 0
    @state = other_nodes.empty? ? :leader : :candidate
    @other_nodes = other_nodes
    @voted_for = []
    @following = nil
    @last_ping = Time.now

    @nodes = @other_nodes.map do |node|
      DRbObject.new_with_uri(node)
    end

    @election = Thread.new do
      @election_timeout = Random.new.rand * 2
      loop do
        sleep @election_timeout
        puts "########## #{@node_address} #{@state}"
        begin
        if @state == :candidate
          @election_timeout = Random.new.rand * 2
          sleep @election_timeout
          @term += 1
          # start campaign
          log "Entering election #{@node_address}, term #{@term}"
          #   1. tell other nodes we're candidate
          votes = @nodes.map do |node|
            #   2. receive some answers
            begin
              vote = node.vote_requested_by(self, @term)
            rescue Exception => e
              log "Some node raised : #{e.message}"
              [No]
            end
          end
          log "Campaign ended : #{votes}"
          #     b. if quorum acquired, let's become the leader
          quorum = votes.reduce(0) { |t,i| t+= i[0] || 0 }
          if quorum >= required_quorum_to_be_elected
            log "My quorum is #{quorum}, i'll become the leader"
            # becoming the leader
            acknowledgements = @nodes.map do |node|
              node.confirm_election_for(self)
            end
            #TODO what if no confirmation?
            log "Became the leader"
            @state = :leader
            break
          else
            log "not becoming the leader, quorum = #{quorum} (required: #{required_quorum_to_be_elected})"
          end

          # try to contact a reknown leader
          votes.each do |vote|
            if vote[0] == No && (node = vote[1])
              log "Got a proposal for a node! #{vote[0]} #{vote[1]}"
              if node.leader?g
                log " this worked"
                @following = node
                break
              else
                # meh
              end
            end
          end

          if @following
            log "I'm finally following #{@following}"
          else
            log "Couldn't find any interesting node"
          end
        else
          #log "Status: #{@state}"
        end
        rescue Exception => e
          puts "Candidate exception #{e.message}"
          raise
        end
      end
    end

    @follower_heartbeat = Thread.new do
      @follower_timeout = Random.new.rand * 2
      loop do
        sleep @follower_timeout
        if @state == :follower
          #@follower_timeout = Random.new.rand * 2
          if Time.now >= @last_ping + @follower_timeout
            log "Where's my master? :-( (#{@following})"
            @state = :candidate
          else
            log "Chilling, my master's somewhere #{Time.now >= @last_ping + @follower_timeout} (#{Time.now} >= #{@last_ping + 2})"
          end
        else
          # do nothing
        end
      end
    end

    @leader_heartbeat = Thread.new do
      @leader_timeout = Random.new.rand / 2
      loop do
        sleep @leader_timeout
        if @state == :leader && !@muted
          @leader_timeout = Random.new.rand  / 2
          all_there = @nodes.map do |node|
            node.still_connected?
          end.all? { |e| e }

          if all_there
            # do nothing
          else
            @state = :candidate
          end
        end
      end
    end
  end

  def still_connected?
    @last_ping = Time.now
  end

  def all_nodes_count
    @other_nodes.length + 1
  end

  def required_quorum_to_be_elected
    ((all_nodes_count / 2.0) + 1).to_i
  end

  Yes = 1
  No  = 0

  def vote_requested_by(node, term)
    raise if @muted
    log " #{node} asked me for a vote with term #{term}, !"
    if @term >= term
      log "nah something's wrong with you node #{node}, not voting for you"
      [No,@following]
    else
      @voted_for << node
      [Yes]
    end
  end

  def confirm_election_for(node)
    raise if @muted
    log "Asked for a confirmation by #{node}"
    if @voted_for.include?(node)
      log "Already voted for #{node}"
      @state = :follower
      @following = node
      @voted_for = []
      log "Became a follower of #{node}"
      [Yes]
    else
      log "HEY NODE #{node}, you're a cheater!"
      [No,@following]
    end
  end

  def status
    if @muted
      raise
    else
    """
[#{@node_address}]    node[node_address:#{@node_address}][state:#{@state}]
[#{@node_address}]      election_timeout=#{@election_timeout}
[#{@node_address}]      other_nodes=#{@other_nodes.inspect}
[#{@node_address}]      following=#{@following}, muted? #{@muted}
[#{@node_address}]      last_ping=#{@last_ping}
"""
    end
  end

  def log(what, important = false)
    puts "[#{@node_address}] #{what}"
  end

  def mute
    @muted = true
  end

  def unmute
    @muted = false
    @state = :candidate
  end

  def to_s
    "#<Node:#{@node_address}>"
  end

  def leader?; @state == :leader; end
  def candidate?; @state == :candidate; end
end
