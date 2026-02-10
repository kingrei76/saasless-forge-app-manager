class BidApp < ApplicationRecord
  belongs_to :bid
  belongs_to :app, optional: true
  has_many :line_items, class_name: "BidLineItem", dependent: :nullify

  validates :app_id, presence: true, unless: :new_app_name?
  validates :new_app_name, presence: true, unless: :app_id?

  def new_app_name?
    new_app_name.present?
  end

  def display_name
    app&.name || new_app_name || "Unnamed App"
  end

  def existing_app?
    app_id.present?
  end

  def new_app?
    new_app_name.present? && app_id.blank?
  end
end
