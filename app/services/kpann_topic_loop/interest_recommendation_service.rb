# frozen_string_literal: true

module KpannTopicLoop
  class InterestRecommendationService
    STATUS_TAGS = %w[精华 新手必看 持续更新].freeze

    def initialize(topic:, user:, guardian:, limit:)
      @topic = topic
      @user = user
      @guardian = guardian
      @limit = [[limit.to_i, 1].max, 10].min
    end

    def call
      return [] unless interest_available?
      return [] if interest.empty?

      scored_candidates.first(limit).map { |candidate| candidate[:topic] }
    end

    private

    attr_reader :topic, :user, :guardian, :limit

    def interest_available?
      defined?(::KpannInterestCore::UserInterest) && user.present? && !user.anonymous?
    end

    def interest
      @interest ||= ::KpannInterestCore::UserInterest.new(user)
    end

    def scored_candidates
      candidates.filter_map do |candidate|
        next if excluded_topic?(candidate)

        candidate_tags = candidate.tags.map(&:name)
        score = interest.score_tags(candidate_tags, current_tag_names: current_tags)
        next if score.blank? || score < SiteSetting.kpann_topic_loop_min_score.to_i

        score += 20 if (candidate_tags & STATUS_TAGS).present?
        score += 15 if candidate.bumped_at && candidate.bumped_at > 30.days.ago
        score += 10 if candidate.posts_count.to_i > 1 || like_count(candidate).positive?
        score -= 80 if read_without_new_posts?(candidate)
        next if score < SiteSetting.kpann_topic_loop_min_score.to_i

        { topic: candidate, score: score }
      end.sort_by { |row| [-row[:score], -sort_time(row[:topic])] }
    end

    def candidates
      tag_names = interest.positive_artist_tags
      return Topic.none if tag_names.blank?

      Topic
        .joins(:tags)
        .where(tags: { name: tag_names })
        .where(archetype: Archetype.default)
        .where(visible: true)
        .where(closed: [true, false])
        .where("topics.id <> ?", topic.id)
        .where("topics.created_at > ?", 2.years.ago)
        .includes(:category, :tags)
        .distinct
        .order("topics.bumped_at DESC NULLS LAST")
        .limit(500)
    end

    def excluded_topic?(candidate)
      return true if candidate.deleted_at.present?
      return true if candidate.category.blank?
      return true if candidate.category.topic_id == candidate.id
      return true unless guardian.can_see?(candidate)
      return true if excluded_categories.include?(candidate.category.slug)
      return true if (candidate.tags.map(&:name) & excluded_tags).present?
      return true if interest.blocked_tags?(candidate.tags.map(&:name))

      false
    end

    def read_without_new_posts?(candidate)
      topic_user = TopicUser.find_by(topic_id: candidate.id, user_id: user.id)
      return false if topic_user.blank?

      topic_user.last_read_post_number.to_i >= candidate.highest_post_number.to_i
    end

    def current_tags
      @current_tags ||= topic.tags.map(&:name)
    end

    def sort_time(candidate)
      (candidate.bumped_at || candidate.created_at || Time.zone.at(0)).to_i
    end

    def like_count(candidate)
      return candidate.like_count.to_i if candidate.respond_to?(:like_count)
      return candidate.public_send(:likes_count).to_i if candidate.respond_to?(:likes_count)

      0
    end

    def excluded_categories
      @excluded_categories ||= split_setting(SiteSetting.kpann_topic_loop_excluded_categories)
    end

    def excluded_tags
      @excluded_tags ||= split_setting(SiteSetting.kpann_topic_loop_excluded_tags)
    end

    def split_setting(value)
      value.to_s.split("|").flat_map { |item| item.split(",") }.map(&:strip).reject(&:blank?)
    end
  end
end

