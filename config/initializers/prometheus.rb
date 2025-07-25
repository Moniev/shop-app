# frozen_string_literal: true

require 'prometheus/client'
require Rails.root.join('app', 'services', 'services', 'instrumentor')

Services::Instrumentor.initialize_metrics
