# frozen_string_literal: true

module KpannTopicLoop
  class RecommendationsController < ::ApplicationController
    requires_plugin KpannTopicLoop::PLUGIN_NAME

    def show
      raise Discourse::NotFound unless SiteSetting.kpann_topic_loop_enabled

      topic = Topic.find_by(id: params[:topic_id].to_i)
      raise Discourse::NotFound if topic.blank?
      raise Discourse::InvalidAccess.new unless guardian.can_see?(topic)

      result =
        RecommendationService.new(
          topic: topic,
          guardian: guardian,
          limit: SiteSetting.kpann_topic_loop_max_items.to_i,
        ).call

      render json: {
               topic_id: topic.id,
               items:
                 result.map do |recommended_topic|
                   SuggestedTopicSerializer.new(recommended_topic, scope: guardian, root: false)
                 end,
             }
    end
  end
end
