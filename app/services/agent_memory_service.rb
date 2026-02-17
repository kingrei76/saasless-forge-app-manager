class AgentMemoryService
  def initialize(agent)
    @agent = agent
  end

  def store(key:, content:, type: "fact", relevance_score: nil, expires_at: nil, metadata: {})
    memory = @agent.agent_memories.find_or_initialize_by(key: key)
    memory.assign_attributes(
      memory_type: type,
      content: content,
      relevance_score: relevance_score,
      metadata: metadata,
      expires_at: expires_at
    )
    memory.save!
    memory
  end

  def recall(key:)
    @agent.agent_memories.find_by(key: key)
  end

  def search(query, type: nil, limit: 10)
    memories = @agent.agent_memories.active
    memories = memories.by_type(type) if type.present?
    memories = memories.where("content ILIKE ?", "%#{query}%") if query.present?
    memories.by_relevance.limit(limit)
  end

  def recent(type: nil, limit: 20)
    memories = @agent.agent_memories.active
    memories = memories.by_type(type) if type.present?
    memories.recent.limit(limit)
  end

  def purge_expired!
    @agent.agent_memories.expired.destroy_all.count
  end

  def clear!(type: nil)
    memories = @agent.agent_memories
    memories = memories.by_type(type) if type.present?
    memories.destroy_all.count
  end

  def self.purge_all_expired!
    AgentMemory.expired.destroy_all.count
  end
end
