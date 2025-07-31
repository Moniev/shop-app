# frozen_string_literal: true

require 'rails_helper'
require 'prometheus/client'
require 'prometheus/client/formats/text'

RSpec.describe Api::V1::DiagnosticsController, type: :controller do
  render_views

  before do
    routes.draw do
      namespace :api do
        namespace :v1 do
          get 'diagnostics/readiness', to: 'diagnostics#readiness'
          get 'diagnostics/health', to: 'diagnostics#health'
          get 'diagnostics#metrics', to: 'diagnostics#metrics'
        end
      end
    end
  end

  let(:diagnostics_service) { instance_double(Services::DiagnosticsService) }

  before do
    allow(Services::DiagnosticsService).to receive(:readiness_probe).and_return(
      status: :ok, message: 'Application is ready'
    )
    allow(Services::DiagnosticsService).to receive(:health_probe).and_return(
      status: :ok, message: 'Application is healthy', details: { database: true, redis: true }
    )
  end

  describe 'GET #readiness' do
    context 'when the application is ready' do
      it 'returns a success status and message' do
        get :readiness, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('ok')
        expect(json_response['message']).to eq('Application is ready')
      end
    end

    context 'when the readiness check fails' do
      it 'returns a service unavailable status and errors' do
        allow(Services::DiagnosticsService).to receive(:readiness_probe).and_return(
          status: :service_unavailable, errors: ['Readiness check failed: DB error']
        )
        get :readiness, format: :json
        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('service_unavailable')
        expect(json_response['errors']).to include('Readiness check failed: DB error')
      end
    end
  end

  describe 'GET #health' do
    context 'when all components are healthy' do
      it 'returns a success status and detailed information' do
        get :health, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('ok')
        expect(json_response['message']).to eq('Application is healthy')
        expect(json_response['details']['database']).to be_truthy
        expect(json_response['details']['redis']).to be_truthy
      end
    end

    context 'when a component is unhealthy' do
      it 'returns a service unavailable status and errors' do
        allow(Services::DiagnosticsService).to receive(:health_probe).and_return(
          status: :service_unavailable,
          errors: ['Redis check failed: Connection refused'],
          details: { database: true, redis: false }
        )
        get :health, format: :json
        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('service_unavailable')
        expect(json_response['errors']).to include('Redis check failed: Connection refused')
        expect(json_response['details']['redis']).to be_falsey
      end
    end
  end

  describe 'GET #metrics' do
    it 'returns metrics in Prometheus text format' do
      allow(Services::Instrumentor).to receive(:registry).and_return(double('registry'))
      allow(Prometheus::Client::Formats::Text).to receive(:marshal).and_return('fake metrics')

      get :metrics

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('fake metrics')
      expect(response.content_type).to eq('text/plain; version=0.0.4; charset=utf-8')
    end
  end
end
