class AppServiceConfig < ApplicationRecord
  belongs_to :app
  belongs_to :service_provider

  validates :app_id, uniqueness: { scope: :service_provider_id }

  scope :enabled, -> { where(enabled: true) }
end
