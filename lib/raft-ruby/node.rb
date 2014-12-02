require 'hansi'
class Node
  MutedException = Class.new(Exception)

  def initialize(node_address, other_nodes = [])
    @muted = false
    @node_address = node_address
    @term  = 0
    other_nodes.empty? ? becomes_leader : becomes_candidate
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
        begin
        if candidate?
          @election_timeout = Random.new.rand * 2
          sleep @election_timeout
          # start campaign
          log "Entering election #{@node_address}, term #{@term}"
          #   1. tell other nodes we're candidate
          new_term = @term + 1
          votes = @nodes.map do |node|
            #   2. receive some answers
            begin
              node.vote_requested_by(self, new_term)
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
            @term += 1
            becomes_leader
            log "Became the leader"
            break
          else
            log "not becoming the leader, quorum = #{quorum} (required: #{required_quorum_to_be_elected})"
          end

          # try to contact a reknown leader
          votes.each do |vote|
            if vote[0] == No && (node = vote[1])&& (term = vote[2])
              log "Got a proposal for #{node}, term #{term}"
              if node.leader?
                log "\tI'm gonna use this node"
                @term = term
                becomes_follower(node)
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
        if follower?
          #@follower_timeout = Random.new.rand * 2
          if Time.now >= @last_ping + @follower_timeout
            log "Where's my master? :-( (#{@following}) #{Time.now >= @last_ping + @follower_timeout} (#{Time.now} >= #{@last_ping + 2})"
            becomes_candidate
          else
            log "Master is #{@following} #{Time.now >= @last_ping + @follower_timeout} (#{Time.now} >= #{@last_ping + @follower_timeout})"
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
        if leader? && !@muted
          @leader_timeout = Random.new.rand  / 2
          all_there = @nodes.map do |node|
            node.still_connected?
          end.all? { |e| e }

          if all_there
            # do nothing
          else
            becomes_candidate
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

  def vote_requested_by(node, proposed_term)
    raise if @muted
    log " #{node} asked me for a vote with term #{proposed_term}, !"
    # if term lower or following someone
    if @following
      log "Node #{node} requesting vote by already following #{@following}"
      [No, @following, @term]
    elsif proposed_term <= @term
      log "Node #{node} proposing term #{proposed_term}, current is #{@term}). Not voting for it"
      [No, @following, @term]
    else
      @voted_for << node
      @term = proposed_term
      [Yes]
    end
  end

  def confirm_election_for(node)
    raise if @muted
    log "Asked for a confirmation by #{node}"
    if @voted_for.include?(node)
      log "Already voted for #{node}"
      becomes_follower(node)
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
      raise MutedException
    else
    """
[#{@node_address}:#{@state}:#{@term}] election_timeout=#{@election_timeout}, muted? #{@muted}
[#{@node_address}:#{@state}:#{@term}] following=#{@following}, last_ping=#{@last_ping}
"""
    end
  end

  def log(what, important = false)
    puts Hansi.render(color, "[#{@node_address}:#{@state}:#{@term}] #{what}")
  end

  def color
    colors = []
    steps  = (0..255).step(15)

    steps.each do |red|
      steps.each { |green| colors << Hansi[ red: red, green: green ]}
      steps.each { |blue|  colors << Hansi[ red: red, green: 255 - blue, blue: blue]}
      steps.each { |blue|  colors << Hansi[ red: red, blue: 255 - blue ]}
    end
    @color_sel ||= colors.shuffle.first
  end
  def mute
    @muted = true
  end

  def unmute
    @muted = false
    becomes_leader
  end

  def to_s
    "#<Node:#{@node_address}>"
  end

  def leader?;    @state == :leader;    end
  def follower?;  @state == :follower;  end
  def candidate?; @state == :candidate; end

  def becomes_leader;    @state = :leader;   @following = nil end
  def becomes_follower(node);  @state = :follower; @following = node; end
  def becomes_candidate; @state = :candidate; @following = nil  end
end
