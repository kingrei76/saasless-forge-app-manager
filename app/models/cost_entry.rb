class CostEntry < ApplicationRecord
  belongs_to :app

  validates :service_name, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :render_entries, -> { where(source_type: "render") }
  scope :manual_entries, -> { where(source_type: nil) }
end
