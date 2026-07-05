import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import GioiThieuListingModal from "discourse/plugins/discourse-sitetor-listing/discourse/components/modal/gioi-thieu-listing";

// Nút "Giới thiệu BĐS của bạn" dưới chân topic Cần mua / Cần thuê:
// mở modal chọn 1 listing trong tài khoản → tạo reply gắn link vào nhu cầu.
export default {
  name: "sitetor-listing-gioi-thieu",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.sitetor_listing_enabled) {
      return;
    }

    const demandIds = (siteSettings.sitetor_listing_demand_categories || "")
      .split("|")
      .map((s) => parseInt(s, 10))
      .filter(Boolean);

    withPluginApi((api) => {
      api.registerTopicFooterButton({
        id: "gioi-thieu-listing",
        icon: "reply",
        priority: 240,
        translatedLabel() {
          return i18n("sitetor_listing.gioi_thieu");
        },
        translatedTitle() {
          return i18n("sitetor_listing.gioi_thieu");
        },
        displayed() {
          return (
            !!this.currentUser && demandIds.includes(this.topic?.category_id)
          );
        },
        action() {
          container
            .lookup("service:modal")
            .show(GioiThieuListingModal, { model: { topic: this.topic } });
        },
      });
    });
  },
};
