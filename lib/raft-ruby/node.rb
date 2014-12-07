require 'logger'

class Node
  MutedException = Class.new(Exception)
  CandidateException = Class.new(Exception)

  attr_reader :following, :nodes, :muted
  attr_reader :node_address
  attr_accessor :term, :last_ping
  def initialize(node_address, other_nodes = [], logger = Logger.new($stout))
    @muted = false
    @logger = logger
    @node_address = node_address
    @term  = 0
    other_nodes.empty? ? becomes_leader : becomes_candidate
    @other_nodes = other_nodes
    @voted_for = []
    @following = nil
    @last_ping = Time.now
    DRb.start_service(@node_address, self)
  end

  def start
    @nodes = @other_nodes.map do |node|
      DRbObject.new_with_uri(node)
    end

    rand = ->(max) { Random.new.rand(max) }
    @leader    = Thread.new { Behaviors::Leader[self,   rand(1.00)] }
    @follower  = Thread.new { Behaviors::Follower[self, rand(0.50)] }
    @candidate = Thread.new { Behaviors::Candidate[self,rand(0.25)] }
    Thread.new do
      sleep 1
      log status
    end
    self#.join
    #@candidate.join; @follower.join; @leader.join
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
      log "Node #{node} requests vote but already follows #{@following}"
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
      [No,@following, @term]
    end
  end

  def status
    if @muted
      raise MutedException
    else
      log "\tmuted?=#{@muted}, following=#{@following}, last_ping=#{@last_ping}"
    end
  end

  def log(what, important = false)
    @logger.log "[#{@node_address}:#{@state}:#{@term}] #{what}"
  end

  def mute
    @muted = true
  end

  def unmute
    @muted = false
    becomes_candidate
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
