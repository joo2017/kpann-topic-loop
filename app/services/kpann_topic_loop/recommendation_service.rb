# frozen_string_literal: true

module KpannTopicLoop
  class RecommendationService
    COMPLEMENTARY = {
      "news" => {
        "wiki" => ["补背景", 30],
        "comeback" => ["追后续", 30],
        "retie" => ["看反应", 30],
        "qa" => ["术语解释", 25],
        "xianliao" => ["继续讨论", 15],
      },
      "retie" => {
        "news" => ["看原事件", 30],
        "wiki" => ["补背景", 30],
        "qa" => ["术语解释", 25],
        "xianliao" => ["继续讨论", 15],
      },
      "wiki" => {
        "news" => ["看近况", 25],
        "comeback" => ["追活动", 30],
        "qa" => ["补术语", 20],
        "retie" => ["看讨论", 20],
        "xianliao" => ["投票/补充", 15],
      },
      "comeback" => {
        "wiki" => ["补艺人信息", 30],
        "news" => ["看回归新闻", 25],
        "qa" => ["补规则", 25],
        "retie" => ["看反应", 20],
      },
      "qa" => {
        "news" => ["真实案例", 25],
        "wiki" => ["相关对象", 25],
        "comeback" => ["相关流程", 20],
        "retie" => ["相关讨论", 20],
      },
      "xianliao" => {
        "wiki" => ["补资料", 20],
        "news" => ["看新闻", 20],
        "qa" => ["看解释", 15],
        "xianliao" => ["继续聊", 12],
      },
      "niming" => {
        "niming" => ["相关吐槽", 15],
        "xianliao" => ["轻量讨论", 12],
      },
    }.freeze

    STATUS_TAGS = %w[精华 新手必看 持续更新].freeze

    def initialize(topic:, guardian:, limit:)
      @topic = topic
      @guardian = guardian
      @limit = [[limit.to_i, 1].max, 10].min
    end

    def call
      build_payload
    end

    private

    attr_reader :topic, :guardian, :limit

    def build_payload
      scored_candidates.first(limit).map { |candidate| candidate[:topic] }
    end

    def scored_candidates
      current_tags = topic.tags.map(&:name)
      return [] if current_tags.blank? && current_slug.blank?

      candidates.filter_map do |candidate|
        next if excluded_topic?(candidate)

        score = score_candidate(candidate, current_tags)
        next if score < SiteSetting.kpann_topic_loop_min_score.to_i

        { topic: candidate, score: score }
      end.sort_by { |row| [-row[:score], -sort_time(row[:topic])] }
    end

    def candidates
      Topic
        .where(archetype: Archetype.default)
        .where(visible: true)
        .where(closed: [true, false])
        .where("topics.id <> ?", topic.id)
        .where("topics.created_at > ?", 2.years.ago)
        .includes(:category, :tags)
        .order("topics.bumped_at DESC NULLS LAST")
        .limit(400)
    end

    def excluded_topic?(candidate)
      return true if candidate.deleted_at.present?
      return true if candidate.category.blank?
      return true if candidate.category.topic_id == candidate.id
      return true unless guardian.can_see?(candidate)
      return true if excluded_categories.include?(candidate.category.slug)
      return true if (candidate.tags.map(&:name) & excluded_tags).present?

      if SiteSetting.kpann_topic_loop_anonymous_safe_mode && current_slug == "niming"
        return !%w[niming xianliao].include?(candidate.category.slug)
      end

      false
    end

    def score_candidate(candidate, current_tags)
      candidate_tags = candidate.tags.map(&:name)
      shared_tags = current_tags & candidate_tags
      score = 0

      artist_overlap = shared_tags & tag_group_names(SiteSetting.kpann_topic_loop_artist_tag_group)
      if artist_overlap.present?
        score += 50
      end

      type_overlap = shared_tags & tag_group_names(SiteSetting.kpann_topic_loop_type_tag_group)
      if type_overlap.present?
        score += 20
      end

      time_overlap = shared_tags & tag_group_names(SiteSetting.kpann_topic_loop_time_tag_group)
      if time_overlap.present?
        score += 15
      end

      source_overlap = shared_tags & tag_group_names(SiteSetting.kpann_topic_loop_source_tag_group)
      if source_overlap.present?
        score += 10
      end

      if candidate.category&.slug == current_slug
        score += 8
      end

      if (candidate_tags & STATUS_TAGS).present?
        score += 20
      end

      complement = COMPLEMENTARY.dig(current_slug, candidate.category&.slug)
      if complement
        _reason, weight = complement
        score += weight
      end

      score += 10 if candidate.bumped_at && candidate.bumped_at > 90.days.ago
      score += 5 if candidate.posts_count.to_i > 1 || like_count(candidate).positive?

      score
    end

    def sort_time(candidate)
      (candidate.bumped_at || candidate.created_at || Time.zone.at(0)).to_i
    end

    def like_count(candidate)
      return candidate.like_count.to_i if candidate.respond_to?(:like_count)
      return candidate.public_send(:likes_count).to_i if candidate.respond_to?(:likes_count)

      0
    end

    def tag_group_names(group_name)
      @tag_group_names ||= {}
      @tag_group_names[group_name] ||=
        begin
          group = TagGroup.find_by_name_insensitive(group_name)
          group ? group.tags.pluck(:name) : []
        end
    end

    def current_slug
      @current_slug ||= topic.category&.slug
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
