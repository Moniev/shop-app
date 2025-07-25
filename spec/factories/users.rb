# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    mail { Faker::Internet.unique.email }
    password { 'password' }
    password_confirmation { 'password' }
    phone { Faker::PhoneNumber.unique.subscriber_number(length: 9) }
    active { true }
    verified { true }
    role { :regular }

    trait :admin do
      role { :admin }
    end

    trait :moderator do
      role { :moderator }
    end

    trait :unactivated do
      active { false }
    end

    trait :unverified do
      verified { false }
    end

    trait :two_factor_enabled do
      after(:create) do |user|
        create(:user_settings, user: user, two_factor_enabled: true)
      end
    end

    trait :with_detail do
      after(:create) do |user|
        create(:user_detail, user: user)
      end
    end
  end

  factory :user_detail do
    user
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
  end

  factory :user_settings do
    user
    two_factor { false }
    night_mode { true }
  end

  factory :activation_code do
    user
    code { SecureRandom.hex(16) }
  end

  factory :verification_code do
    user
    code { SecureRandom.hex(16) }
  end

  factory :second_factor_code do
    user
    code { SecureRandom.hex(8) }
  end

  factory :reset_code do
    user
    code { SecureRandom.hex(16) }
    expires_at { 2.hours.from_now }
  end

  factory :blacklisted_token do
    association :owner, factory: :user
    token { SecureRandom.hex(32) }
    expires_at { 24.hours.from_now }
  end
end
