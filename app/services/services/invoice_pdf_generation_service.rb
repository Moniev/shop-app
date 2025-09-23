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
      items = invoice_items
      serialized_items = serialize_invoice_items(items)
      pdf_document = generate_pdf(serialized_items)
      pdf_document.render
    end

    def invoice_items
      @invoice.invoice_items
    end

    def serialize_invoice_items(items)
      table_data = [['Lp.', 'Usługa/Produkt', 'Ilość', 'J.m.', 'Cena jednostkowa netto', 'Cena łączna netto', 'VAT',
                     'Łączna wartość brutto']]
      update_items(table_data, items)
      generate_pdf(table_data)
    end

    private

    def update_items(table_data, items)
      items.each_with_index { |item, index| table_data << format_item(item, index) }
      items
    end

    def format_item(item, index)
      [
        index + 1,
        item.name,
        item.quantity,
        item.unit_of_measure,
        format('%.2f zł', item.net_price),
        format('%.2f zł', item.total_net_price),
        "#{item.vat_rate.to_i}%",
        format('%.2f zł', item.total_gross_price)
      ]
    end

    def generate_pdf(table_data)
      Prawn::Document.new do |pdf|
        pdf.font_families.update('DejaVuSans' => {
                                   normal: Rails.root.join('app/assets/fonts/DejaVuSans.ttf'),
                                   bold: Rails.root.join('app/assets/fonts/DejaVuSans-Bold.ttf')
                                 })
        pdf.font 'DejaVuSans'

        pdf.text "Faktura nr #{@invoice.number}", size: 20, style: :bold
        pdf.move_down 20

        pdf.table(table_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'DDDDDD'
        end
      end
    end
  end
end
