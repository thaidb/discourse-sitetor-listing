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

    # Đăng ký matcher vào ngôn ngữ /filter (TopicsFilter) — giao diện power-user,
    # dùng chung SQL với thanh filter phía trên. Cú pháp:
    #   /filter?q=category:listing price-min:50tr price-max:5ty frontage-min:8
    #            area-min:100 type:"Nhà mặt phố" position:hẻm direction:đông
    # Giá: hậu tố tr=triệu, ty/tỷ=tỷ; số trần < 100000 hiểu là TRIỆU; còn lại VND.
    def self.register_topics_filter!(plugin)
      RANGE_PARAMS.each do |param, (field_proc, op)|
        name = param.to_s.tr("_", "-")
        plugin.add_filter_custom_filter(name) do |scope, values, _guardian|
          raw = SitetorListing::DiscoveryFilters.strip_quotes(Array(values).last.to_s)
          val = param.to_s.start_with?("price") ? parse_price(raw) : raw.to_f
          if SiteSetting.sitetor_listing_enabled && val && val > 0
            range_join(scope, field_proc.call, param, op, val)
          else
            scope
          end
        end
      end

      MULTI_PARAMS.each do |param, field_proc|
        plugin.add_filter_custom_filter(param.to_s) do |scope, values, _guardian|
          list =
            Array(values)
              .flat_map { |v| SitetorListing::DiscoveryFilters.strip_quotes(v.to_s).split(",") }
              .map(&:strip)
              .reject(&:blank?)
          if SiteSetting.sitetor_listing_enabled && list.any?
            values_join_ci(scope, field_proc.call, param, list)
          else
            scope
          end
        end
      end
    end

    # Giá trị có ngoặc kép (type:"Nhà mặt phố") đến tay custom filter còn nguyên
    # ngoặc — core chỉ strip trong các matcher riêng của nó.
    def self.strip_quotes(value)
      value.gsub(/\A["']|["']\z/, "")
    end

    def self.parse_price(raw)
      v = raw.to_s.downcase.strip
      num = v.to_f
      return nil if num <= 0
      if v.include?("ty") || v.include?("tỷ")
        (num * 1_000_000_000).round
      elsif v.include?("tr")
        (num * 1_000_000).round
      elsif num < 100_000
        (num * 1_000_000).round # số trần mặc định hiểu là triệu
      else
        num.round # VND
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

    # Bản không phân biệt hoa thường cho cú pháp /filter (user gõ tay position:hẻm)
    def self.values_join_ci(scope, field, param, values)
      scope.joins(<<~SQL).where("LOWER(df_ci_#{param}.value) IN (?)", values.map(&:downcase))
        INNER JOIN topic_custom_fields df_ci_#{param}
          ON df_ci_#{param}.topic_id = topics.id
          AND df_ci_#{param}.name = '#{field}'
      SQL
    end
  end
end
