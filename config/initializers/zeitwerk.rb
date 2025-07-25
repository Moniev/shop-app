# frozen_string_literal: true

Rails.autoloaders.main do |autoloader|
  autoloader.inflector.inflect('authentication_service' => 'Services::AuthenticationService')
end
