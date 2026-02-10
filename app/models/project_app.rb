class ProjectApp < ApplicationRecord
  belongs_to :project
  belongs_to :app, optional: true

  validates :app_id, presence: true, unless: :new_app_name?
  validates :new_app_name, presence: true, unless: :app_id?

  scope :with_app, -> { where.not(app_id: nil) }
  scope :pending_creation, -> { where(app_id: nil).where.not(new_app_name: nil) }
  scope :primary, -> { where(primary: true) }

  def new_app_name?
    new_app_name.present?
  end

  def display_name
    app&.name || new_app_name || "Unnamed App"
  end

  def existing_app?
    app_id.present?
  end

  def pending_app?
    new_app_name.present? && app_id.blank?
  end

  def link_to_app!(app)
    update!(app: app, new_app_name: nil)
  end
end
