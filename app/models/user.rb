class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { admin: 0, partner: 1 }

  has_many :github_accounts, dependent: :destroy
  has_many :audit_logs, dependent: :nullify
  has_many :assigned_projects, class_name: "Project", foreign_key: :assignee_id, dependent: :nullify
  has_many :time_entries, dependent: :nullify

  before_create :generate_api_token

  def self.find_or_create_from_oauth(provider:, uid:, email:, name:, avatar_url: nil)
    user = find_by(provider: provider, uid: uid) || find_by(email: email)

    if user
      user.update(provider: provider, uid: uid, avatar_url: avatar_url) if user.uid.blank?
    else
      user = create!(
        provider: provider,
        uid: uid,
        email: email,
        name: name,
        avatar_url: avatar_url,
        password: SecureRandom.hex(16),
        role: :admin
      )
    end

    user
  end

  protected

  def password_required?
    return false if provider.present?
    super
  end

  private

  def generate_api_token
    self.api_token = SecureRandom.hex(32)
  end
end
