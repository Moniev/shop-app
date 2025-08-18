# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    alias_action :update_location, :update_details, :update_entrepreneur_details, to: :update_specifics
    alias_action :me, :logout, :actions, to: :profile_actions

    user ||= User.new

    can :read, Product
    can :create, User

    return unless user.persisted?

    cannot :role, User

    if user.activated?
      can %i[like unlike rate comment], Product
      can %i[manage update_specifics profile_actions], User, id: user.id
    end

    if user.verified?
      can :manage, :cart
      can :create, Payment
      can :show, Payment, order: { user_id: user.id }
      can :create, Refund
      can %i[show cancel], Refund, user_id: user.id
      can %i[create read cancel], Order, user_id: user.id
    end

    if user.admin?
      can :manage, :all
    elsif user.moderator?
      can :read, :all
      can :update, [Product, Order, Payment, Refund]
      can :manage, Comment
    elsif user.regular?
      can :read, Comment
      can :read, Item, user_id: user.id
      can %i[update destroy], Comment, user_id: user.id
      cannot :index, User
    end
  end
end
