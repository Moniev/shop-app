# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    association :user

    status { :pending }
    payment_status { :unpaid }
    order_date { Time.current }
    delivery_address { 'ul. Testowa 1, 00-001 Warszawa' }

    total_amount { 0.0 }

    trait :with_items do
      transient do
        items_count { 2 }
      end

      after(:create) do |order, evaluator|
        create_list(:item, evaluator.items_count, order: order)
        order.reload
      end
    end

    trait :paid do
      payment_status { :paid }

      after(:create) do |order|
        create(:payment, order: order, status: :completed, amount: order.total_amount)
      end
    end

    trait :shipped do
      status { :shipped }
    end

    trait :delivered do
      status { :delivered }
      payment_status { :paid }
    end
  end
end
