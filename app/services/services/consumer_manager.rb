# frozen_string_literal: true

module Services
  class ConsumerManager
    include BunnySubscriber::Consumer
  end
end
