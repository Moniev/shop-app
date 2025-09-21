# frozen_string_literal: true

class InvoiceObserver < ApplicationObserver
  observe :invoice

  def after_create(invoice)
    Rails.logger.info "Invoice has been created with ID: #{invoice.id}"
    result = Services::InvoicePDFGenerationService.call(invoice)
  end
end
