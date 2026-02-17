class AgentMemory < ApplicationRecord
  belongs_to :agent

  validates :content, presence: true
  validates :memory_type, inclusion: { in: %w[conversation fact preference context] }
  validates :key, uniqueness: { scope: :agent_id }, allow_nil: true

  scope :by_type, ->(t) { where(memory_type: t) }
  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :by_relevance, -> { order(relevance_score: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  MEMORY_TYPES = %w[conversation fact preference context].freeze
end
