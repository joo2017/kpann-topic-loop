# kpann-topic-loop

Discourse plugin for Kpann-style topic loop recommendations.

The plugin adds a native More Topics tab named `闭环推荐` on topic pages. It follows the current Discourse MoreTopics extension pattern:

- `api.registerMoreTopicsTab`
- `BasicTopicList`
- `TopicView` / `TopicViewPosts` serializers
- `SuggestedTopicSerializer`

Recommendations are scored by shared tag groups, category loop relationships, status tags, recency, and light engagement signals.

## Settings

- `kpann_topic_loop_enabled`
- `kpann_topic_loop_max_items`
- `kpann_topic_loop_min_score`
- `kpann_topic_loop_excluded_categories`
- `kpann_topic_loop_excluded_tags`
- `kpann_topic_loop_anonymous_safe_mode`
- `kpann_topic_loop_artist_tag_group`
- `kpann_topic_loop_type_tag_group`
- `kpann_topic_loop_source_tag_group`
- `kpann_topic_loop_time_tag_group`
- `kpann_topic_loop_status_tag_group`

## Compatibility

Tested on Discourse `2026.5.0-latest`.

