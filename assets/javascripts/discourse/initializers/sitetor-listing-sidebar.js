import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

// Thêm link "Tìm bất động sản" vào sidebar (mục Cộng đồng) — bấm từ bất kỳ
// trang nào cũng quay về /listing (bộ lọc gốc, không query param).
export default {
  name: "sitetor-listing-sidebar",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.sitetor_listing_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.addCommunitySectionLink((baseSectionLink) => {
        return class SitetorListingSectionLink extends baseSectionLink {
          name = "sitetor-listing";
          route = "listing";
          text = i18n("sitetor_listing.title");
          title = i18n("sitetor_listing.title");
          defaultPrefixValue = "magnifying-glass";
        };
      });
    });
  },
};
