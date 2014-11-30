require 'drb/drb'

# The URI for the server to connect to
URIs=%w(
  druby://localhost:8787
  druby://localhost:8788
  druby://localhost:8789
)

class Node
  def initialize(index, other_nodes)
    @muted = false
    @index = index
    @term  = 0
    @state = :candidate
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
        puts "########## #{@index} #{@state}"
        begin
        if @state == :candidate
          @election_timeout = Random.new.rand * 2
          sleep @election_timeout
          @term += 1
          # start campaign
          log "Entering election #{@index}, term #{@term}"
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
              if node.is_leader?
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

  def is_leader?
    @state == :leader
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
[#{@index}]    node[index:#{@index}][state:#{@state}]
[#{@index}]      election_timeout=#{@election_timeout}
[#{@index}]      other_nodes=#{@other_nodes.inspect}
[#{@index}]      following=#{@following}, muted? #{@muted}
[#{@index}]      last_ping=#{@last_ping}
"""
    end
  end

  def log(what, important = false)
    puts "[#{@index}] #{what}"
  end

  def mute
    @muted = true
  end

  def unmute
    @muted = false
    @state = :candidate
  end

  def to_s
    "#<Node:#{@index}>"
  end
end


URIs.each_with_index do |uri, index|
  thread = Thread.new {
    other_nodes = URIs.clone
    other_nodes.delete_at(index)
    puts "Creating a new node #{index}, #{other_nodes}"
    DRb.start_service(uri, Node.new(index, other_nodes))
  }
  thread.join
end

nodes||=[]
nodes[0] = DRbObject.new_with_uri(URIs[0])
nodes[1] = DRbObject.new_with_uri(URIs[1])
nodes[2] = DRbObject.new_with_uri(URIs[2])
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
