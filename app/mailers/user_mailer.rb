# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def self.dial_2fa_code(user, code)
    @user = user
    @cide = code
    mail(to: @user.mail, subject: 'Your 2FA code')
  end

  def self.dial_activation_code(user, code)
    @user = user
    @cide = code
    mail(to: @user.mail, subject: 'Activation of your account')
  end

  def self.dial_reset_code(user, code)
    @user = user
    @cide = code
    mail(to: @user.mail, subject: 'Your reset code')
  end

  def self.dial_notification(user, type)
  end

  def self.dial_advertisements(users, type)
  end
end
