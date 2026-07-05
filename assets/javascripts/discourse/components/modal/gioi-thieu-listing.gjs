import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

// Modal "Giới thiệu listing": liệt kê tin đăng của chính user trong các
// category listing (Bán/Cho thuê), chọn 1 tin → tạo reply gắn link vào
// topic nhu cầu (Discourse tự onebox link thành card).
export default class GioiThieuListingModal extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked listings = null; // null = đang tải
  @tracked selectedId = null;
  @tracked saving = false;

  constructor() {
    super(...arguments);
    this.loadListings();
  }

  get listingCategoryIds() {
    return (this.siteSettings.sitetor_listing_categories || "")
      .split("|")
      .map((s) => parseInt(s, 10))
      .filter(Boolean);
  }

  async loadListings() {
    try {
      const res = await ajax(
        `/topics/created-by/${this.currentUser.username}.json`
      );
      this.listings = (res.topic_list?.topics || []).filter((t) =>
        this.listingCategoryIds.includes(t.category_id)
      );
    } catch (e) {
      this.listings = [];
      popupAjaxError(e);
    }
  }

  @action
  select(id) {
    this.selectedId = id;
  }

  @action
  async send() {
    const chosen = this.listings?.find((t) => t.id === this.selectedId);
    if (!chosen) {
      return;
    }
    this.saving = true;
    try {
      await ajax("/posts.json", {
        type: "POST",
        data: {
          topic_id: this.args.model.topic.id,
          raw: `${i18n("sitetor_listing.gioi_thieu")}:\n\n${window.location.origin}/t/${chosen.slug}/${chosen.id}`,
        },
      });
      this.args.closeModal();
      window.location.reload();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "sitetor_listing.gioi_thieu_title"}}
      @closeModal={{@closeModal}}
      class="gioi-thieu-modal"
    >
      <:body>
        {{#if (eq this.listings null)}}
          <p>…</p>
        {{else if this.listings.length}}
          <p>{{i18n "sitetor_listing.gioi_thieu_hint"}}</p>
          <ul class="gioi-thieu-list">
            {{#each this.listings as |t|}}
              <li>
                <label>
                  <input
                    type="radio"
                    name="gt-listing"
                    checked={{eq this.selectedId t.id}}
                    {{on "change" (fn this.select t.id)}}
                  />
                  <span>{{t.title}}</span>
                </label>
              </li>
            {{/each}}
          </ul>
        {{else}}
          <p>{{i18n "sitetor_listing.gioi_thieu_khong_co"}}</p>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          @action={{this.send}}
          @label="sitetor_listing.gioi_thieu_gui"
          @disabled={{this.saving}}
          class="btn-primary"
        />
        <DButton @action={{@closeModal}} @label="sitetor_listing.dong" />
      </:footer>
    </DModal>
  </template>
}
