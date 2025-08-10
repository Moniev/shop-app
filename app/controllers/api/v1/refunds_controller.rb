# frozen_string_literal: true

class RefundsController < Api::ApplicationController
  load_and_authorize_resource

  def index; end

  def show; end

  def me; end

  def update; end

  def destroy; end

  private

  def refund_params; end

  def set_refund
    params.require(:refund).permit
  end

  def bind_data_and_render
  end

  def handle_error_reponse
  end
end
