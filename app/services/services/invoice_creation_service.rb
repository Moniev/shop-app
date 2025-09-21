# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class InvoiceCreationService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    def self.call(payment)
      new(payment: payment).call
    end

    def initialize(payment)
      @payment = payment
    end

    def call
      with_error_handling do
        ActiveRecord::Base.transaction do
          order = find_order_with_details
          invoice = build_invoice(order)
          build_invoice_items(invoice, order)
          invoice.save!

          succes_result(data: { invoice: invoice }, message: 'Invoice created successfully', status: :created)
        end
      end
    end

    private

    def find_order_with_details
      order_id = @payment.order_id
      Order.includes({ user: { user_detail: %i[entrepreneur_detail locations] } }, { items: :product },
                     :location).find(order_id)
    end

    def generate_invoice_number
      current_month_prefix = Date.current.strftime('%Y/%m')

      last_invoice = Invoice.where('number LIKE ?', "FV/#{current_month_prefix}/%").order(created_at: :desc).first

      new_sequence_number = 1
      if last_invoice
        last_sequence_number = last_invoice.number.split('/').last.to_i
        new_sequence_number = last_sequence_number + 1
      end

      "FV/#{current_month_prefix}/#{new_sequence_number}"
    end

    def build_invoice(order)
      buyer = order.user
      details = buyer.user_detail
      Invoice.new(
        full_addres: order.location.full_address,
        invoice_number: generate_invoice_number,
        buyer_name: buyer.entrepreneur? ? buyer.user_detail.full_name : details.entrepreneur_detail.business_name,
        buyer_tax_id: buyer.entrepreneur? ? details.entrepreneur_detail.nip : nil,
        sale_date: @payment.created_at,
        due_date: @payment.created_at + 14.days,
        payment: @payment,
        order: order,
        location: order.location
      )
    end

    def build_invoice_items(invoice, order)
      order.items.each do |item|
        net_value = item.quantity * item.price_at_purchase
        vat_value = net_value * (item.product.vat_rate / 100)
        gross_value = net_value + vat_value

        invoice.invoice_items.build(
          invoice: invoice,
          product: item.product,
          name: item.product.name,
          quantity: item.quantity,
          net_price: item.price,
          vat_rate: item.product.vat_rate,
          unit_of_measure: item.product.unit_of_measure,
          total_net_price: net_value,
          total_vat_price: vat_value,
          total_gross_price: gross_value
        )
      end
    end
  end
end
