# frozen_string_literal: true

module Services
  class ConsumerManager
    extend BunnySubscriber::Consumer
  end
end
