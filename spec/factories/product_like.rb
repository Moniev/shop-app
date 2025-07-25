# frozen_string_literal: true

FactoryBot.define do
  factory :product_like do
    association :user
    association :product
  end
end
