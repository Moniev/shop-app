# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Test Product #{n}" }
    price { Faker::Commerce.price(range: 10..1000.0) }
    description { Faker::Lorem.sentence }
  end

  factory :product_photo do
    association :product
    after(:build) do |product_photo|
      unless product_photo.image.attached?
        product_photo.image.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/test_image.png')),
          filename: 'test_image.png',
          content_type: 'image/png'
        )
      end
    end
  end
end
