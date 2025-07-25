# frozen_string_literal: true

FactoryBot.define do
  factory :user_action do
    association :user
    action_type { 'login' }
    action { 'User logged in successfully' }
  end
end
