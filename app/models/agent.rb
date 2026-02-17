class Agent < ApplicationRecord
  belongs_to :service_provider, optional: true
  belongs_to :ai_model, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :agent_versions, dependent: :destroy
  has_many :agent_tools, dependent: :destroy
  has_many :tool_definitions, through: :agent_tools
  has_many :agent_handoffs, foreign_key: :source_agent_id, dependent: :destroy
  has_many :incoming_handoffs, class_name: "AgentHandoff", foreign_key: :target_agent_id, dependent: :destroy
  has_many :agent_goals, dependent: :destroy
  has_many :agent_triggers, dependent: :destroy
  has_many :agent_executions, dependent: :destroy
  has_many :agent_memories, dependent: :destroy
  has_many :agent_alerts, dependent: :destroy

  validates :name, :slug, :category, :status, :mode, presence: true
  validates :slug, uniqueness: true
  validates :max_iterations, numericality: { greater_than: 0 }, allow_nil: true
  validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }, allow_nil: true
  validates :status, inclusion: { in: %w[draft active paused archived] }
  validates :mode, inclusion: { in: %w[test live] }
  validates :category, inclusion: { in: %w[billing payments support data orchestrator custom] }

  scope :active, -> { where(status: "active") }
  scope :by_status, ->(s) { where(status: s) }
  scope :by_category, ->(c) { where(category: c) }
  scope :by_mode, ->(m) { where(mode: m) }
  scope :test_mode, -> { where(mode: "test") }
  scope :live_mode, -> { where(mode: "live") }

  STATUSES = %w[draft active paused archived].freeze
  CATEGORIES = %w[billing payments support data orchestrator custom].freeze
  MODES = %w[test live].freeze

  before_validation :generate_slug, on: :create

  def activate!
    update!(status: "active")
  end

  def pause!
    update!(status: "paused")
  end

  def archive!
    update!(status: "archived")
  end

  def toggle_mode!
    update!(mode: mode == "test" ? "live" : "test")
  end

  def test_mode?
    mode == "test"
  end

  def live_mode?
    mode == "live"
  end

  def enabled_tools
    agent_tools.where(enabled: true).includes(:tool_definition)
  end

  def status_badge_color
    case status
    when "active"   then "success"
    when "paused"   then "warning"
    when "archived" then "ghost"
    else "info"
    end
  end

  def category_badge_color
    case category
    when "billing"      then "primary"
    when "payments"     then "secondary"
    when "support"      then "accent"
    when "data"         then "info"
    when "orchestrator" then "warning"
    else "ghost"
    end
  end

  private

  def generate_slug
    return if slug.present?
    self.slug = name&.parameterize
  end
end
