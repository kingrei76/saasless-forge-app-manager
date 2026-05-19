FactoryBot.define do
  factory :bid do
    association :client
    sequence(:title) { |n| "Bid #{n}" }
    status { "draft" }
    hourly_rate { 150 }
    wizard_state { {} }
  end
end
