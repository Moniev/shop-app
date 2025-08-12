# frozen_string_literal: true

module Api
  module V1
    class RefundsController < Api::ApplicationController
      before_action :set_order
      before_action :set_refund, only: %i[update]
      load_and_authorize_resource

      def create
        result = Services::RefundCreationService.call(
          user: current_user,
          refund_params: refund_params
        )
        bind_data_and_render(result, 'show')
      end

      def index
        @refunds = Refund.accessible_by(current_ability).includes(:order).refund(created_at: :desc)
        bind_data_and_render(nil, 'index')
      end

      def show
        bind_data_and_render(nil, 'show')
      end

      def me
        @refunds = current_user.refunds.includes(:refunds).refund(created_at: :desc)
        bind_data_and_render(nil, 'index')
      end

      def update
        result = Services::RefundUpdateService.call(@refund, update_refund_params)
        bind_data_and_render(result, 'show')
      end

      def destroy
        result = Services::RefundDeletionService.call(@refund)
        handle_destroy_response(result)
      end

      private

      def update_refund_params
      end

      def refund_params
        params.fetch(:refund, {}).permit(:status, :payment_status)
      end

      def set_order
        @order = Order.find_by(id: params[:order_id])
      end

      def set_refund
        params.require(:refund).permit
      end

      def bind_data_and_render(result, view_name)
        if result
          bind_data(result)
          if @success
            if @data.key?(:refund)
              @refund = data[:refund]
            elsif @data.key?(:refunds)
              @refunds = @data[:products] if @data.key?(:refunds)
            end
          end
        else

        end
      end

      def handle_error_reponse
      end

      def handle_destroy_response
      end
    end
  end
end
