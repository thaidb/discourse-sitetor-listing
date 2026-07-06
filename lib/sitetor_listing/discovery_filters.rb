# frozen_string_literal: true

# Lọc topic list GỐC của Discourse (trang category /c/...) theo custom fields BĐS
# qua query param URL — TopicQuery.add_custom_filter tự whitelist param.
# Frontend: theme component sitetor-category-filters đăng ký cùng bộ param
# bằng api.addDiscoveryQueryParam (thanh filter sau breadcrumb).
#
# Lưu ý alias join: mỗi PARAM một alias riêng (df_<param>) — min và max của cùng
# một field là 2 custom filter độc lập, dùng chung alias theo field sẽ trùng JOIN.
module SitetorListing
  module DiscoveryFilters
    RANGE_PARAMS = {
      price_min: [-> { SitetorListing::FIELD_PRICE }, ">="],
      price_max: [-> { SitetorListing::FIELD_PRICE }, "<="],
      frontage_min: [-> { SitetorListing::FIELD_FRONTAGE }, ">="],
      frontage_max: [-> { SitetorListing::FIELD_FRONTAGE }, "<="],
      area_min: [-> { SitetorListing::FIELD_AREA }, ">="],
      area_max: [-> { SitetorListing::FIELD_AREA }, "<="],
    }.freeze

    MULTI_PARAMS = {
      type: -> { SitetorListing::FIELD_TYPE },
      position: -> { SitetorListing::FIELD_POSITION },
      direction: -> { SitetorListing::FIELD_DIRECTION },
    }.freeze

    def self.register!
      RANGE_PARAMS.each do |param, (field_proc, op)|
        TopicQuery.add_custom_filter(param) do |results, topic_query|
          val = topic_query.options[param]
          if SiteSetting.sitetor_listing_enabled && val.present?
            results = range_join(results, field_proc.call, param, op, val)
          end
          results
        end
      end

      MULTI_PARAMS.each do |param, field_proc|
        TopicQuery.add_custom_filter(param) do |results, topic_query|
          raw = topic_query.options[param]
          values = raw.to_s.split(",").map(&:strip).reject(&:blank?)
          if SiteSetting.sitetor_listing_enabled && values.any?
            results = values_join(results, field_proc.call, param, values)
          end
          results
        end
      end
    end

    def self.range_join(scope, field, param, op, val)
      scope.joins(<<~SQL).where("CAST(df_#{param}.value AS numeric) #{op} ?", val.to_f)
        INNER JOIN topic_custom_fields df_#{param}
          ON df_#{param}.topic_id = topics.id
          AND df_#{param}.name = '#{field}'
          AND df_#{param}.value ~ '^\\d+(\\.\\d+)?$'
      SQL
    end

    def self.values_join(scope, field, param, values)
      scope.joins(<<~SQL).where("df_#{param}.value IN (?)", values)
        INNER JOIN topic_custom_fields df_#{param}
          ON df_#{param}.topic_id = topics.id
          AND df_#{param}.name = '#{field}'
      SQL
    end
  end
end
