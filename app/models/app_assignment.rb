class AppAssignment < ApplicationRecord
  belongs_to :app
  belongs_to :client

  validates :app_id, uniqueness: { scope: :client_id }
end
