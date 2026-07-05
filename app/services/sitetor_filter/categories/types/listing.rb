# frozen_string_literal: true

# Category type "Listing" trong wizard tạo category (/new-category/setup):
# tạo category kiểu này → ID tự thêm vào setting sitetor_filter_categories,
# tức là tin trong đó (và mọi sub-category) được parse + lọc tại /listing.
module SitetorFilter
  module Categories
    module Types
      class Listing < ::Categories::Types::Base
        type_id :sitetor_listing

        class << self
          def enable_plugin
            SiteSetting.sitetor_filter_enabled = true
          end

          def plugin_enabled?
            SiteSetting.sitetor_filter_enabled
          end

          def category_matches?(category)
            setting_ids.include?(category.id)
          end

          def find_matches
            Category.where(id: setting_ids)
          end

          def configure_category(category, guardian:, configuration_values: {})
            configure_custom_fields(category, guardian:, configuration_values:)
            update_setting(setting_ids | [category.id], guardian)
          end

          def unconfigure_category(category, guardian:)
            update_setting(setting_ids - [category.id], guardian)
          end

          def configuration_schema
            {
              general_category_settings: {
                name: {
                  default: I18n.t("category_types.sitetor_listing.name"),
                  type: :string,
                },
                style_type: {
                  default: "emoji",
                  type: :string,
                },
                emoji: {
                  default: "house",
                  type: :string,
                },
              },
              site_settings: {
              },
              category_custom_fields: {
              },
              site_texts: {
              },
            }
          end

          def icon
            "house"
          end

          private

          def setting_ids
            SiteSetting.sitetor_filter_categories.split("|").map(&:to_i).reject(&:zero?)
          end

          def update_setting(ids, guardian)
            SiteSetting.set_and_log(
              "sitetor_filter_categories",
              ids.uniq.join("|"),
              guardian&.user || Discourse.system_user,
            )
          end
        end
      end
    end
  end
end
