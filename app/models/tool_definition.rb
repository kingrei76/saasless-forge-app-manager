class ToolDefinition < ApplicationRecord
  has_many :agent_tools, dependent: :destroy
  has_many :agents, through: :agent_tools
  has_many :tool_versions, dependent: :destroy
  has_many :tool_credentials, dependent: :destroy
  has_many :agent_execution_steps, dependent: :nullify

  validates :name, :slug, :category, :status, :risk_level, presence: true
  validates :slug, uniqueness: true
  validates :status, inclusion: { in: %w[active deprecated disabled] }
  validates :risk_level, inclusion: { in: %w[low medium high critical] }
  validates :category, inclusion: { in: %w[api database file communication code other] }

  scope :active, -> { where(status: "active") }
  scope :by_category, ->(c) { where(category: c) }
  scope :by_risk_level, ->(r) { where(risk_level: r) }

  CATEGORIES = %w[api database file communication code other].freeze
  RISK_LEVELS = %w[low medium high critical].freeze
  STATUSES = %w[active deprecated disabled].freeze

  def risk_badge_color
    case risk_level
    when "low"      then "success"
    when "medium"   then "warning"
    when "high"     then "error"
    when "critical" then "error"
    else "ghost"
    end
  end

  def status_badge_color
    case status
    when "active"     then "success"
    when "deprecated" then "warning"
    when "disabled"   then "ghost"
    else "info"
    end
  end
end
