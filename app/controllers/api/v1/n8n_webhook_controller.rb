# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    class N8nWebhookController < Api::ApplicationController
      skip_before_action :authenticate_user!

    end
  end
end
