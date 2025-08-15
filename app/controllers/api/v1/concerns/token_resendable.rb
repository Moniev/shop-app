module Api
  module V1
    module Concerns
      module TokenResendable
        extend ActiveSupport::Concern
        def request_2fa_code_resend
          result = Services::AuthenticationService.send_2fa_code(@user)
          bind_data_and_render(result, 'shared/message')
        end

        def request_activation_code_resend
          return unless @user.unactivated?

          result = Services::UserManagementService.resend_activation_code(@user)
          bind_data_and_render(result, 'shared/message')
        end

        def request_verification_code_resend
          return unless @user.unverified?

          result = Services::UserManagementService.resend_verification_code(@user)
          bind_data_and_render(result, 'shared/message')
        end

        def request_reset_code_resend
          result = Services::PasswordResetService.resend_reset_code(params[:mail])
          bind_data_and_render(result, 'shared/message')
        end
      end
    end
  end
end
