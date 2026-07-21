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

    const site = container.lookup("service:site");

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

      // Section "Mô hình kinh doanh" — toàn site, mỗi ngành → /demand/<slug>.
      // Dữ liệu preload trong Site JSON (site.sitetor_business_models). Đặt tên
      // section = slug để theme "Sidebar Menu Reorder" (#207) có thể định vị.
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          class IndustryLink extends BaseCustomSidebarSectionLink {
            constructor(bm) {
              super(...arguments);
              // KHÔNG dùng tên `model` — base class đã có getter `model` (no setter)
              this.bm = bm;
            }
            get name() {
              return `sitetor-bm-${this.bm.slug}`;
            }
            get classNames() {
              return "sitetor-bm-link";
            }
            get href() {
              // Trang tag native /c/mapping theo ngành (SEO index + kết hợp bộ
              // lọc tag/range native). url dựng sẵn backend (industry_links) gồm
              // slug + tag_id. Fallback /demand nếu thiếu (an toàn khi cache cũ).
              return this.bm.url || `/demand/${this.bm.slug}`;
            }
            get text() {
              return this.bm.name.replaceAll("-", " ");
            }
            get title() {
              return this.bm.name.replaceAll("-", " ");
            }
            // Emoji nhiều màu (Twemoji) thay icon đơn sắc. Core bọc thành
            // `:${value}:` rồi chạy dReplaceEmoji → ảnh emoji. Value đã xác thực
            // tồn tại trong Emoji registry ở backend (INDUSTRY_EMOJI).
            get prefixType() {
              return "emoji";
            }
            get prefixValue() {
              return this.bm.emoji || "briefcase";
            }
          }

          return class SitetorBusinessModelsSection extends BaseCustomSidebarSection {
            name = "sitetor-business-models";

            get text() {
              return i18n("sitetor_listing.business_models");
            }
            get title() {
              return i18n("sitetor_listing.business_models");
            }
            get collapsedByDefault() {
              return false;
            }
            get displaySection() {
              return (site.sitetor_business_models || []).length > 0;
            }
            get links() {
              return (site.sitetor_business_models || []).map(
                (m) => new IndustryLink(m)
              );
            }
          };
        }
      );
    });
  },
};
