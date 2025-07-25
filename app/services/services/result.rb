# frozen_string_literal: true

module Services
  Result = Struct.new(:success?, :data, :status, :errors, :message, keyword_init: true)
end
