FactoryBot.define do
  factory :product_rate do
    association :user
    association :product
    rating { rand(1..5) }
    comment { Faker::Lorem.sentence }
  end
end
