# frozen_string_literal: true

require 'prawn'

module Services
  class InvoicePDFGenerationService
    def self.call(invoice)
      new(invoice: invoice).call
    end

    def initialize(invoice:)
      @invoice = invoice
    end

    def call
      items = get_invoice_items
      serialized_items = serialize_invoice_items(items)
      pdf_document = generate_pdf(serialized_items)
      pdf_document.render
    end

    def get_invoice_items
      @invoice.invoice_items
    end

    def serialize_invoice_items(items)
      table_data = [['Lp.', 'Usługa/Produkt', 'Ilość', 'J.m.', 'Cena jednostkowa netto', 'Cena łączna netto', 'VAT',
                     'Łączna wartość brutto']]

      items.each_with_index do |item, index|
        table_data << [
          index + 1,
          item.name,
          item.quantity,
          item.unit_of_measure,
          item.net_price,
          format('%.2f zł', item.total_net_price),
          "#{item.vat_rate.to_i}%",
          format('%.2f zł', item.total_gross_price)
        ]
      end

      table_data
    end

    def generate_pdf
      Prawn::Document.new do |pdf|
      end
    end
  end
end
