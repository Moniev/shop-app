FactoryBot.define do
  factory :product_like do
    association :user
    association :product
  end
end
