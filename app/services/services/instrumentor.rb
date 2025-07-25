# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class Instrumentor
    def self.initialize_metrics
      @registry = Prometheus::Client.registry

      @registry.counter(
        :diagnostics_checks_total,
        docstring: 'Diagnostics total score',
        labels: [:check_type]
      )

      @registry.gauge(
        :diagnostics_component_up,
        docstring: 'Components status',
        labels: [:component]
      )

      @registry.counter(
        :diagnostics_component_errors_total,
        docstring: 'Error per component',
        labels: [:component]
      )
    end

    def self.check_performed(type)
      @registry&.get(:diagnostics_checks_total)&.increment(labels: { check_type: type })
    end

    def self.report_component_status(component, is_up:, error: false)
      return unless @registry

      status = is_up ? 1 : 0
      @registry.get(:diagnostics_component_up).set(status, labels: { component: component })

      return unless error

      @registry.get(:diagnostics_component_errors_total).increment(labels: { component: component })
    end

    class << self
      attr_reader :registry
    end
  end
end
