# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    association :user
    status { :pending }
    payment_status { :unpaid }
    association :location

    trait :with_items do
      transient do
        items_count { 2 }
      end

      after(:create) do |order, evaluator|
        create_list(:item, evaluator.items_count, order: order, price_at_purchase: 99.99)
        order.reload
        order.save!
      end
    end

    trait :paid do
      payment_status { :paid }

      after(:create) do |order|
        create(:payment, :paid, order: order, amount: order.total_amount)
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

  factory :item do
    association :product
    association :order
    quantity { 1 }
    price_at_purchase { product.price }

    trait :in_cart do
      order { nil }
      association :user
    end
  end

  factory :cart_item, class: 'Item' do
    association :user
    association :product
    quantity { 1 }
    price_at_purchase { product.price }
    order { nil }
  end
end
