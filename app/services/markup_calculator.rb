class MarkupCalculator
  # Resolve effective markup: app_assignment > client > global Setting
  def self.for(app:, client:)
    assignment = AppAssignment.find_by(app: app, client: client)

    markup = assignment&.markup_percentage ||
             client&.markup_percentage ||
             Setting[:default_markup_percentage]&.to_f ||
             30.0

    markup.to_f
  end

  def self.apply(cost:, markup_percentage:)
    cost * (1 + markup_percentage / 100.0)
  end
end
