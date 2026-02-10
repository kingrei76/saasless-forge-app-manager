class AuditLogger
  def self.log(user:, action:, auditable: nil, changes_data: {})
    AuditLog.create!(
      user: user,
      action: action,
      auditable: auditable,
      changes_data: changes_data
    )
  end
end
