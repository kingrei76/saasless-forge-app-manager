class AllowedEmail < ApplicationRecord
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email" }

  before_validation :normalize_email

  def self.allowed?(email)
    where("LOWER(email) = ?", email.to_s.downcase.strip).exists?
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip if email.present?
  end
end
