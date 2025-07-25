# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles diagnostic endpoints for monitoring application status.
    #
    # This controller provides readiness, health, and metrics endpoints, commonly
    # used by orchestration systems like Kubernetes to manage the application lifecycle.
    class DiagnosticsController < ApplicationController
      skip_before_action :authenticate_user!

      # GET /api/v1/diagnostics/readiness
      #
      # Checks if the application is ready to accept traffic.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   a status response, typically with HTTP status 200 (OK) or 503 (Service Unavailable).
      # @see Services::DiagnosticsService.readiness_probe
      def readiness
        result = Services::DiagnosticsService.readiness_probe
        bind_data(result)
      end

      # GET /api/v1/diagnostics/health
      #
      # Checks the ongoing health of the application and its dependencies.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render a
      #   detailed health status, typically with HTTP status 200 (OK) or 503 (Service Unavailable).
      # @see Services::DiagnosticsService.health_probe
      def health
        result = Services::DiagnosticsService.health_probe
        bind_data(result)
        @details = result[:details]
      end

      # GET /api/v1/diagnostics/metrics
      #
      # Exposes application metrics in Prometheus text format.
      #
      # This endpoint is designed to be scraped by a Prometheus server, providing
      # performance and business metrics for monitoring and alerting.
      #
      # @return [void] Renders metrics as plain text with a
      #   `text/plain; version=0.0.4` content type and a 200 OK status.
      # @see Services::PrometheusInstrumentor
      def metrics
        exporter = Prometheus::Client::Formats::Text.new
        render plain: exporter.export(Services::PrometheusInstrumentor.registry),
               content_type: 'text/plain; version=0.0.4'
      end

      private

      # Binds common data from a service result object to controller instance variables.
      # Assumes result object has :status, :message, and :errors keys (or methods).
      # @param result [Hash, Services::Result] The result object from a service call.
      def bind_data(result)
        @status = result[:status]
        @message = result[:message]
        @errors = result[:errors]
      end
    end
  end
end
