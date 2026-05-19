FactoryBot.define do
  factory :github_account do
    association :user
    sequence(:account_name) { |n| "github-account-#{n}" }
  end
end
