# frozen_string_literal: true

FactoryBot.define do
  factory :item do
    association :product
    association :order
    user { nil }
    quantity { 1 }
    price_at_purchase { product.price }

    trait :in_cart do
      order { nil }
      association :user
    end
  end
end
