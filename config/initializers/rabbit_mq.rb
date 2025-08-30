# frozen_string_literal: true

RABBIT_CONFIG = {
  host: ENV.fetch('RABBIT_HOST', credentials.fetch(:host, '127.0.0.1')),
  port: ENV.fetch('RABBIT_PORT', credentials.fetch(:port, 5672)),
  vhost: ENV.fetch('RABBIT_VHOST', credentials.fetch(:vhost, '/')),
  user: ENV.fetch('RABBIT_USER', credentials.fetch(:user)),
  password: ENV.fetch('RABBIT_PASSWORD', credentials.fetch(:password)),
  heartbeat: ENV.fetch('RABBIT_HEARTBEAT', credentials.fetch(:heartbeat, :server)),
  frame_max: ENV.fetch('RABBIT_FRAME_MAX', credentials.fetch(:frame_max, 131_072)),
  auth_mechanism: ENV.fetch('RABBIT_AUTH_MECHANISM', credentials.fetch(:auth_mechanism, 'PLAIN'))
}
