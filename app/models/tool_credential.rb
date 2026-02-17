class ToolCredential < ApplicationRecord
  encrypts :encrypted_value

  belongs_to :tool_definition

  validates :name, presence: true, uniqueness: { scope: :tool_definition_id }
  validates :credential_type, presence: true,
    inclusion: { in: %w[oauth api_key password bearer_token custom] }
  validates :status, inclusion: { in: %w[active expired revoked] }

  scope :active, -> { where(status: "active") }
  scope :expired, -> { where(status: "expired").or(where("expires_at < ?", Time.current)) }

  CREDENTIAL_TYPES = %w[oauth api_key password bearer_token custom].freeze

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def masked_value
    return nil if encrypted_value.blank?
    val = encrypted_value.to_s
    return "****" if val.length <= 8
    "#{val[0..3]}#{"*" * [val.length - 8, 4].max}#{val[-4..]}"
  end
end
