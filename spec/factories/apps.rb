FactoryBot.define do
  factory :app do
    association :github_account
    sequence(:name) { |n| "app-#{n}" }
    sequence(:full_name) { |n| "owner/app-#{n}" }
  end
end
