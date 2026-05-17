import { tracked } from "@glimmer/tracking";
import BasicTopicList from "discourse/components/basic-topic-list";
import { withPluginApi } from "discourse/lib/plugin-api";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const KpannTopicLoop = <template>
  <div
    role="complementary"
    aria-labelledby="kpann-topic-loop-title"
    id="kpann-topic-loop"
    class="more-topics__list"
  >
    <h3 id="kpann-topic-loop-title" class="more-topics__list-title">
      {{dIcon "link"}}{{i18n "kpann_topic_loop.title"}}
    </h3>

    <div class="topics">
      <BasicTopicList
        @topics={{@topic.kpannTopicLoopTopics}}
        @listContext="kpann-topic-loop"
      />
    </div>
  </div>
</template>;

const KpannInterestTopics = <template>
  <div
    role="complementary"
    aria-labelledby="kpann-interest-topics-title"
    id="kpann-interest-topics"
    class="more-topics__list"
  >
    <h3 id="kpann-interest-topics-title" class="more-topics__list-title">
      {{dIcon "bell"}}{{i18n "kpann_topic_loop.interest_title"}}
    </h3>

    <div class="topics">
      <BasicTopicList
        @topics={{@topic.kpannInterestTopics}}
        @listContext="kpann-interest-topics"
      />
    </div>
  </div>
</template>;

export default {
  name: "kpann-topic-loop",

  initialize(container) {
    const settings = container.lookup("service:site-settings");

    if (!settings.kpann_topic_loop_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.registerMoreTopicsTab({
        id: "kpann-topic-loop",
        name: i18n("kpann_topic_loop.tab"),
        icon: "link",
        component: KpannTopicLoop,
        condition: ({ topic }) => topic.kpannTopicLoopTopics?.length,
      });

      api.registerMoreTopicsTab({
        id: "kpann-interest-topics",
        name: i18n("kpann_topic_loop.interest_tab"),
        icon: "bell",
        component: KpannInterestTopics,
        condition: ({ topic }) => topic.kpannInterestTopics?.length,
      });

      api.modifyClass(
        "model:topic",
        (Superclass) =>
          class extends Superclass {
            @tracked _kpannTopicLoopRecords = null;
            @tracked _kpannInterestTopicRecords = null;

            // Only updates if we have data - preserves cache when scrolling.
            set kpann_topic_loop(value) {
              if (value?.length) {
                this._kpannTopicLoopRecords = value.map((topic) =>
                  this.store.createRecord("topic", topic)
                );
              }
            }

            get kpannTopicLoopTopics() {
              return this._kpannTopicLoopRecords;
            }

            set kpann_interest_topics(value) {
              if (value?.length) {
                this._kpannInterestTopicRecords = value.map((topic) =>
                  this.store.createRecord("topic", topic)
                );
              }
            }

            get kpannInterestTopics() {
              return this._kpannInterestTopicRecords;
            }
          }
      );

      api.modifyClass(
        "model:post-stream",
        (Superclass) =>
          class extends Superclass {
            _setSuggestedTopics(result) {
              super._setSuggestedTopics(...arguments);

              if (result.kpann_topic_loop) {
                this.topic.kpann_topic_loop = result.kpann_topic_loop;
              }

              if (result.kpann_interest_topics) {
                this.topic.kpann_interest_topics = result.kpann_interest_topics;
              }
            }
          }
      );
    });
  },
};
