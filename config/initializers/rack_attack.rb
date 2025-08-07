# frozen_string_literal: true

class Rack::Attack
  self.enabled = false if Rails.env.test?

  cache.store = ActiveSupport::Cache::MemoryStore.new

  blocklist('block probes/scanners') do |req|
    Rack::Attack::Fail2Ban.filter(req.ip, maxretry: 0, findtime: 1.day, bantime: 1.day) do
      req.path.to_s.match?(%r{/wp-admin|/wp-login\.php|/\.env|/phpmyadmin|/adminer|/\.git/config})
    end
  end

  throttle('req/ip', limit: 60, period: 60) do |req|
    req.ip
  end

  throttle('logins/email+ip', limit: 6, period: 60) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      [req.params['mail'].to_s.downcase.gsub(/\s+/, ''),
       req.ip]
    end
  end

  throttle('2fa/ip', limit: 5, period: 60) do |req|
    req.ip if req.path == '/api/v1/auth/verify_2fa' && req.post?
  end

  throttle('password_reset/ip', limit: 3, period: 1.hour) do |req|
    req.ip if req.path == '/api/v1/auth/password/reset' && req.post?
  end

  throttle('users/create', limit: 4, period: 1.hour) do |req|
    req.ip if req.path == '/api/v1/users/create' && req.post?
  end

  track('not_found/ip', limit: 10, period: 5.minutes) do |req|
    req.env['rack.attack.rack_attack_track_not_found']
  end

  self.throttled_responder = lambda do |env|
    req = ActionDispatch::Request.new(env)
    ActiveSupport::Notifications.instrument('rack.attack.throttle', { request: req })
    [429, { 'Content-Type' => 'application/json' }, [{ error: 'Throttle limit exceeded' }.to_json]]
  end
end

ActiveSupport::Notifications.subscribe(/rack\.attack/) do |name, _start, _finish, _request_id, payload|
  req = payload[:request]
  if name == 'rack.attack.throttle'
    Rails.logger.warn "[rack-attack] Throttled request from IP: #{req.ip} to path: #{req.path}"
  end
end
