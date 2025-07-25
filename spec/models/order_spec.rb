# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order, type: :model do
  before do
    allow_any_instance_of(CartObserver).to receive(:after_create)
    allow_any_instance_of(CartObserver).to receive(:after_update)
  end

  let!(:admin) { create(:user, role: :admin) }
  let(:user) { create(:user) }
  let(:product1) { create(:product, price: 100) }
  let(:product2) { create(:product, price: 50) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:items).dependent(:destroy) }
    it { should have_many(:products).through(:items) }
    it { should have_one(:payment).dependent(:destroy) }
    it { should accept_nested_attributes_for(:items).allow_destroy(true) }
  end

  describe 'enums' do
    it {
      should define_enum_for(:status).with_values(pending: 0, processing: 1, shipped: 2, delivered: 3, cancelled: 4,
                                                  refunded: 5).with_prefix
    }
    it { should define_enum_for(:payment_status).with_values(unpaid: 0, paid: 1, failed: 2, refunded: 3).with_prefix }
  end

  describe 'validations' do
    it { should validate_presence_of(:total_amount) }
    it { should validate_numericality_of(:total_amount).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:payment_status) }

    it 'is invalid without an order_date on update' do
      order = create(:order)
      order.order_date = nil
      expect(order).not_to be_valid
      expect(order.errors[:order_date]).to include("can't be blank")
    end
  end

  describe 'scopes' do
    it '.recent returns the 10 most recent orders, ordered by date' do
      order1 = create(:order, order_date: 1.day.ago)
      order2 = create(:order, order_date: Time.current)
      order3 = create(:order, order_date: 2.days.ago)

      expect(Order.recent).to eq([order2, order1, order3])
    end

    it '.completed returns delivered orders' do
      delivered_order = create(:order, status: :delivered)
      create(:order, status: :pending)

      expect(Order.completed).to eq([delivered_order])
    end

    it '.pending_payment returns unpaid orders' do
      unpaid_order = create(:order, payment_status: :unpaid)
      create(:order, payment_status: :paid)

      expect(Order.pending_payment).to eq([unpaid_order])
    end
  end

  describe 'callbacks' do
    it 'sets order_date on creation' do
      order = build(:order, order_date: nil)
      order.valid?
      expect(order.order_date).to be_present
    end

    it 'calculates total_amount before save' do
      order = create(:order, user: user)
      create(:item, order: order, product: product1, quantity: 2, price_at_purchase: 100)
      create(:item, order: order, product: product2, quantity: 1, price_at_purchase: 50)
      order.save!
      order.reload
      expect(order.total_amount).to eq(250)
    end
  end

  describe 'instance methods' do
    let(:order) { create(:order, :with_items, user: user, items_count: 3) }

    it '#total_items_count returns the correct sum of quantities' do
      order.items.first.update!(quantity: 5)
      expect(order.total_items_count).to eq(7)
    end

    it '#accessible_by? returns true for the owner and admin' do
      expect(order.accessible_by?(user)).to be true
      expect(order.accessible_by?(admin)).to be true
    end

    it '#accessible_by? returns false for another user' do
      other_user = create(:user)
      expect(order.accessible_by?(other_user)).to be false
    end

    it '#manageable_by? returns true for an admin' do
      expect(order.manageable_by?(admin)).to be true
    end

    it '#manageable_by? returns false for a regular user' do
      expect(order.manageable_by?(user)).to be false
    end
  end

  describe '.for_user' do
    it 'returns all orders for an admin' do
      create_list(:order, 2)
      expect(Order.for_user(admin).count).to eq(2)
    end

    it "returns only the user's orders for a regular user" do
      user_order = create(:order, user: user)
      create(:order)
      expect(Order.for_user(user)).to eq([user_order])
    end
  end

  describe '.create_from_cart_for' do
    let(:user_with_cart) { create(:user) }

    context "when the user's cart is not empty" do
      before do
        create(:item, :in_cart, user: user_with_cart, product: product1, quantity: 2)
        create(:item, :in_cart, user: user_with_cart, product: product2, quantity: 1)
      end

      it 'creates a new order' do
        expect { Order.create_from_cart_for(user_with_cart) }.to change(Order, :count).by(1)
      end

      it 'assigns items from the cart to the new order' do
        result = Order.create_from_cart_for(user_with_cart)
        order = result[:order]
        expect(user_with_cart.cart_items.count).to eq(0)
        expect(order.items.count).to eq(2)
      end

      it 'correctly calculates the total amount of the order' do
        result = Order.create_from_cart_for(user_with_cart)
        order = result[:order]
        expect(order.total_amount).to eq(250)
      end

      it 'returns the created order and no errors' do
        result = Order.create_from_cart_for(user_with_cart)
        expect(result[:order]).to be_a(Order)
        expect(result[:errors]).to be_empty
      end
    end

    context "when the user's cart is empty" do
      it 'does not create a new order' do
        expect { Order.create_from_cart_for(user) }.not_to change(Order, :count)
      end

      it 'returns an error message' do
        result = Order.create_from_cart_for(user)
        expect(result[:order]).to be_nil
        expect(result[:errors]).to include('Your cart is empty')
      end
    end
  end
end
