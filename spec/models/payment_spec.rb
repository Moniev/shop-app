# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payment, type: :model do
  let(:order) { create(:order) }

  describe 'associations' do
    it { should belong_to(:order) }
  end

  describe 'enums' do
    it do
      should define_enum_for(:status)
        .with_values(unpaid: 0, paid: 1, failed: 2, refunded: 3)
        .with_prefix
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:payment_method) }

    it 'validates uniqueness of transaction_id' do
      create(:payment, order: order, transaction_id: 'unique_tx_123')
      should validate_uniqueness_of(:transaction_id).allow_nil
    end

    context 'when status is paid' do
      subject { build(:payment, :paid, order: order) }

      it { should validate_presence_of(:stripe_charge_id) }

      it 'is invalid on update without a currency' do
        payment = create(:payment, :paid, order: order)
        payment.currency = nil
        expect(payment).not_to be_valid
        expect(payment.errors[:currency]).to include("can't be blank")
      end
    end

    context 'when status is not paid' do
      subject { build(:payment, status: :unpaid, order: order) }

      it { should_not validate_presence_of(:stripe_charge_id) }
      it { should_not validate_presence_of(:currency) }
    end
  end

  describe 'callbacks' do
    describe '#set_default_currency' do
      it 'sets the currency to PLN on creation if not provided' do
        payment = build(:payment, order: order, currency: nil)
        payment.valid?
        expect(payment.currency).to eq('PLN')
      end

      it 'does not override an existing currency' do
        payment = build(:payment, order: order, currency: 'USD')
        payment.valid?
        expect(payment.currency).to eq('USD')
      end
    end
  end

  describe 'instance methods' do
    let(:payment) { create(:payment, order: order, status: :unpaid, stripe_charge_id: 'ch_xyz789') }

    describe '#mark_as_paid!' do
      it 'updates the status to paid' do
        payment.mark_as_paid!
        expect(payment.status).to eq('paid')
      end
    end

    describe '#mark_as_failed!' do
      let(:unpaid_payment) { create(:payment, order: order, status: :unpaid) }

      it 'updates the status to failed' do
        unpaid_payment.mark_as_failed!
        expect(unpaid_payment.status).to eq('failed')
      end

      it 'sets the error_message when provided' do
        error_msg = 'Insufficient funds'
        unpaid_payment.mark_as_failed!(error_msg)
        expect(unpaid_payment.error_message).to eq(error_msg)
      end
    end
  end

  describe 'creation' do
    it 'is valid with valid attributes' do
      payment = build(:payment, order: order)
      expect(payment).to be_valid
    end

    it 'is invalid without an order' do
      payment = build(:payment, order: nil)
      expect(payment).not_to be_valid
    end
  end
end
