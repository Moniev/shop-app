# frozen_string_literal: true

class InvoicePDFCreationJob < ApplicationJob
  queue_as :default

  def perform(payment)
    Services::InvoicePDFGenerationService.call(payment)
  end
end
