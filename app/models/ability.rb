# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    can :read, Product

    return unless user.persisted?

    can %i[like rate comment], Product
    can :manage, :cart
    can :create, Payment
    can :show, Payment, order: { user_id: user.id }

    can :create, Order
    can :read, Order, user_id: user.id
    can :cancel, Order, user_id: user.id

    can :manage, User, id: user.id
    cannot :role, User

    if user.admin?
      can :manage, :all
    elsif user.moderator?
      can :read, [Product, Order, Payment, Comment, Item, BlacklistedToken, User]
      can :update, Product
      can :update, Order
      can :update, Payment
      can :manage, Comment
    elsif user.regular?
      can :read, [Product, Comment, Item]
      can :read, Payment, order: { user_id: user.id }
      cannot :index, User unless user.admin?
    end
  end
end
