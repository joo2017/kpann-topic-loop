# frozen_string_literal: true

# name: kpann-topic-loop
# about: Kpann content loop recommendations for Discourse topics.
# version: 0.1.0
# authors: OpenAI Codex
# required_version: 3.4.0

enabled_site_setting :kpann_topic_loop_enabled

module ::KpannTopicLoop
  PLUGIN_NAME = "kpann-topic-loop"
end

after_initialize do
  require_dependency File.expand_path("app/services/kpann_topic_loop/recommendation_service.rb", __dir__)
  require_dependency File.expand_path("app/controllers/kpann_topic_loop/recommendations_controller.rb", __dir__)

  add_to_class(:topic_view, :kpann_topic_loop) do
    if topic.private_message? || !SiteSetting.kpann_topic_loop_enabled
      return nil
    end

    guardian = Guardian.new(@user)

    @kpann_topic_loop ||=
      KpannTopicLoop::RecommendationService.new(
        topic: topic,
        guardian: guardian,
        limit: SiteSetting.kpann_topic_loop_max_items.to_i,
      ).call
  end

  %i[topic_view TopicViewPosts].each do |serializer|
    add_to_serializer(
      serializer,
      :kpann_topic_loop,
      include_condition: -> { SiteSetting.kpann_topic_loop_enabled },
    ) do
      if object.next_page.nil? && !object.topic.private_message?
        object.kpann_topic_loop&.map do |topic|
          SuggestedTopicSerializer.new(topic, scope: scope, root: false)
        end
      end
    end
  end

  Discourse::Application.routes.append do
    get "/kpann-topic-loop/:topic_id.json" => "kpann_topic_loop/recommendations#show",
        defaults: { format: :json },
        constraints: { topic_id: /\d+/ }
    get "/kpann-topic-loop/:topic_id" => "kpann_topic_loop/recommendations#show",
        defaults: { format: :json },
        constraints: { topic_id: /\d+/ }
  end
end
