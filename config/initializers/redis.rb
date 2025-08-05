# frozen_string_literal: true

class Redis
  class << self
    attr_accessor :current
  end
end

redis_config = {}

if Rails.env.development? || Rails.env.test?
  redis_config = {
    host: 'localhost',
    port: 6379,
    ssl: false
  }

elsif Rails.env.production?
  redis_config = {
    host: Rails.application.credentials.redis[:host],
    port: Rails.application.credentials.redis[:port],
    password: Rails.application.credentials.redis[:password],
    ssl: true
  }
end

Redis.current = ConnectionPool.new(size: 10, timeout: 5) do
  Redis.new(redis_config)
end
