# frozen_string_literal: true

module Api
  module V1
    class RefundsController < Api::ApplicationController
      load_and_authorize_resource :order, only: %i[create index]
      load_and_authorize_resource :refund, through: :order, only: %i[create index]
      load_and_authorize_resource :refund, except: %i[create index me]

      def create
        result = Services::RefundCreationService.call(
          user: current_user,
          order: @order,
          refund_params: refund_params
        )
        bind_data_and_render(result, :show)
      end

      def index
        @refunds = Refund.accessible_by(current_ability).includes(:order).order(created_at: :desc)
        bind_data_and_render(nil, :index)
      end

      def show
        bind_data_and_render(nil, :show)
      end

      def me
        @refunds = current_user.refunds.includes(:order).order(created_at: :desc)
        bind_data_and_render(nil, :index)
      end

      def update
        result = Services::RefundUpdateService.call(@refund, update_refund_params)
        bind_data_and_render(result, :show)
      end

      def destroy
        result = Services::RefundDeletionService.call(@refund)
        handle_destroy_response(result)
      end

      def cancel
        result = refund_management_service.cancel
        bind_data_and_render(result, :cancel)
      end

      def complete
        result = refund_management_service.complete
        bind_data_and_render(result, :complete)
      end

      private

      def refund_management_service
        @refund_management_service ||= Services::RefundManagementService.new(@refund)
      end

      def update_refund_params
        params.require(:refund).permit(:status, :reason, :description)
      end

      def refund_params
        params.fetch(:refund).permit(:reason, :description)
      end

      def bind_data_and_render(result, view_name = nil)
        if result
          bind_data(result)
          if @success
            @refund = @data[:refund] if @data.key?(:refund)
            @refunds = @data[:refunds] if @data.key?(:refunds)

            if view_name
              render view_name, status: @status
            else
              render json: { message: @message }, status: @status
            end
          else
            render json: { errors: @errors }, status: @status
          end
        else
          render view_name, status: :ok
        end
      end

      def handle_error_response(errors, status = :unprocessable_entity)
        render json: { errors: errors }, status: status
      end

      def handle_destroy_response(result)
        if result.success?
          head :no_content
        else
          handle_error_response(result.errors)
        end
      end
    end
  end
end
