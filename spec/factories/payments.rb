# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    association :order

    amount { 100.00 }
    status { :unpaid }
    payment_method { 'stripe' }
    currency { 'pln' }

    sequence(:transaction_id) { |n| "tx_#{SecureRandom.hex(8)}#{n}" }

    error_message { nil }
    stripe_charge_id { nil }

    trait :paid do
      status { :paid }
      sequence(:stripe_charge_id) { |n| "ch_#{SecureRandom.hex(8)}#{n}" }
    end

    trait :failed do
      status { :failed }
      error_message { 'Your card was declined.' }
    end

    trait :refunded do
      status { :refunded }
      sequence(:stripe_charge_id) { |n| "ch_#{SecureRandom.hex(8)}#{n}" }
    end
  end
end
