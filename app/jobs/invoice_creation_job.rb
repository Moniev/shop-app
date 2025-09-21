# frozen_string_literal: true

class InvoiceCreationJob < ApplicationJob
  queue_as :default

  def perform(payment)
    Services::InvoiceCreationService.call(payment)
  end
end
