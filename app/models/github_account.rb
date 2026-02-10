class GithubAccount < ApplicationRecord
  encrypts :access_token
  encrypts :render_api_key

  belongs_to :user
  has_many :apps, dependent: :destroy
  has_many :render_services, through: :apps

  validates :account_name, presence: true
  validates :access_token, presence: true

  scope :with_render, -> { where.not(render_api_key: [nil, ""]) }

  def display_name
    label.presence || account_name
  end

  def render_configured?
    render_api_key.present?
  end

  def has_render_account?
    render_configured?
  end
end

