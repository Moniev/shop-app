# frozen_string_literal: true

json.cache! ['user_actions', @user.id, @actions.map(&:id).sort, @actions.maximum(:created_at) || Time.current,
             params[:page]] do
  json.actions @actions do |action|
    json.id action.id
    json.action_type action.action_type

    json.action action.action
    json.created_at action.created_at
  end

  if @actions.respond_to?(:current_page)
    json.meta do
      json.current_page @actions.current_page
      json.next_page @actions.next_page
      json.prev_page @actions.prev_page
      json.total_pages @actions.total_pages
      json.total_count @actions.total_count
    end
  end
end
