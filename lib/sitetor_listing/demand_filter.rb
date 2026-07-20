# frozen_string_literal: true

# Query lọc topic NHU CẦU (Cần mua/Cần thuê) cho trang /demand (JSON) và
# card mặc định của category Mapping. Nhu cầu là BỘ LỌC LƯU SẴN nên:
#   - tiêu chí phân loại/khu vực là multi-value (JSON array) → khớp "chứa" 1 trong
#     các giá trị đã chọn (OR trong cùng field, AND giữa các field);
#   - ngân sách/diện tích/mặt tiền là RANGE (from/to) → khớp GIAO NHAU (overlap)
#     với khoảng người dùng nhập.
# Trả {total:, topics:}. serialize(t) trả toàn bộ demand_* để vẽ card.
module SitetorListing
  module DemandFilter
    # param (số nhiều) → custom field JSON array
    JSON_MULTI = {
      "property_types" => SitetorListing::FIELD_DEMAND_PROPERTY_TYPES,
      "provinces" => SitetorListing::FIELD_DEMAND_PROVINCES,
      "districts" => SitetorListing::FIELD_DEMAND_DISTRICTS,
      "wards" => SitetorListing::FIELD_DEMAND_WARDS,
      "streets" => SitetorListing::FIELD_DEMAND_STREETS,
      "directions" => SitetorListing::FIELD_DEMAND_DIRECTIONS,
      "positions" => SitetorListing::FIELD_DEMAND_POSITIONS,
      "purpose" => SitetorListing::FIELD_DEMAND_PURPOSE,
      "industry" => SitetorListing::FIELD_DEMAND_INDUSTRY,
      "view" => SitetorListing::FIELD_DEMAND_VIEW,
    }.freeze

    SORTS = {
      "budget_asc" => [SitetorListing::FIELD_BUDGET_FROM, "ASC"],
      "budget_desc" => [SitetorListing::FIELD_BUDGET_TO, "DESC"],
      "area_desc" => [SitetorListing::FIELD_AREA_TO, "DESC"],
    }.freeze

    module_function

    # f: { q:, budget_min:, budget_max:, area_min:, area_max:, frontage_min:,
    #      frontage_max:, demand_type: [..], multi: {"provinces"=>[..], ...},
    #      sort:, page: }
    def run(f, category_ids, per:)
      scope = Topic.visible.listable_topics.where(category_id: category_ids)

      if f[:q].present?
        scope = scope.where("topics.title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(f[:q])}%")
      end

      scope = overlap(scope, SitetorListing::FIELD_BUDGET_FROM, SitetorListing::FIELD_BUDGET_TO, f[:budget_min], f[:budget_max])
      scope = overlap(scope, SitetorListing::FIELD_AREA_FROM, SitetorListing::FIELD_AREA_TO, f[:area_min], f[:area_max])
      scope = overlap(scope, SitetorListing::FIELD_FRONTAGE_FROM, SitetorListing::FIELD_FRONTAGE_TO, f[:frontage_min], f[:frontage_max])

      if f[:demand_type].present?
        scope = by_string(scope, SitetorListing::FIELD_DEMAND_TYPE, Array(f[:demand_type]))
      end

      (f[:multi] || {}).each do |param, values|
        field = JSON_MULTI[param]
        scope = json_any(scope, field, values) if field && values.present?
      end

      total = scope.count
      page = f[:page].to_i
      topics = sort(scope, f[:sort]).offset(page * per).limit(per)
      { total: total, topics: topics }
    end

    # Multi-value JSON array: value lưu dạng ["Quận 1","Quận 3"]. Khớp nếu chứa
    # BẤT KỲ giá trị nào đã chọn — tìm chuỗi con bọc ngoặc kép ("Quận 1") để
    # tránh khớp nhầm một phần từ (dùng bind param + sanitize LIKE).
    def json_any(scope, field, values)
      scope = scope.joins(<<~SQL)
        INNER JOIN topic_custom_fields jm_#{field}
          ON jm_#{field}.topic_id = topics.id
          AND jm_#{field}.name = '#{field}'
      SQL
      clauses = values.map { "jm_#{field}.value LIKE ?" }
      args = values.map { |v| "%\"#{ActiveRecord::Base.sanitize_sql_like(v.to_s)}\"%" }
      scope.where(clauses.join(" OR "), *args)
    end

    # Single-value string (demand_type): value IN (?)
    def by_string(scope, field, values)
      scope.joins(<<~SQL).where("sm_#{field}.value IN (?)", values)
        INNER JOIN topic_custom_fields sm_#{field}
          ON sm_#{field}.topic_id = topics.id
          AND sm_#{field}.name = '#{field}'
      SQL
    end

    # Range của nhu cầu [from,to] GIAO NHAU với [min,max] người dùng nhập.
    # Chỉ 1 đầu range được set thì coi như điểm (COALESCE). Nhu cầu không set
    # đầu nào của range này thì bị loại khi có filter (LEFT JOIN → null).
    def overlap(scope, from_field, to_field, min, max)
      return scope if min.blank? && max.blank?

      scope = numeric_join(scope, from_field)
      scope = numeric_join(scope, to_field)
      lo = "COALESCE(CAST(nf_#{from_field}.value AS numeric), CAST(nf_#{to_field}.value AS numeric))"
      hi = "COALESCE(CAST(nf_#{to_field}.value AS numeric), CAST(nf_#{from_field}.value AS numeric))"
      scope = scope.where("nf_#{from_field}.value IS NOT NULL OR nf_#{to_field}.value IS NOT NULL")
      scope = scope.where("#{lo} <= ?", max.to_f) if max.present?
      scope = scope.where("#{hi} >= ?", min.to_f) if min.present?
      scope
    end

    def numeric_join(scope, field)
      scope.joins(<<~SQL)
        LEFT JOIN topic_custom_fields nf_#{field}
          ON nf_#{field}.topic_id = topics.id
          AND nf_#{field}.name = '#{field}'
          AND nf_#{field}.value ~ '^\\d+(\\.\\d+)?$'
      SQL
    end

    def sort(scope, key)
      field, dir = SORTS[key.to_s]
      return scope.order(bumped_at: :desc) unless field

      scope
        .joins(<<~SQL)
          LEFT JOIN topic_custom_fields ds_#{field}
            ON ds_#{field}.topic_id = topics.id
            AND ds_#{field}.name = '#{field}'
            AND ds_#{field}.value ~ '^\\d+(\\.\\d+)?$'
        SQL
        .order(Arel.sql("CAST(ds_#{field}.value AS numeric) #{dir} NULLS LAST, topics.bumped_at DESC"))
    end

    def parse_list(raw)
      return [] if raw.blank?
      parsed = JSON.parse(raw)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    def serialize(t)
      cf = t.custom_fields
      {
        id: t.id,
        title: t.title,
        slug: t.slug,
        category_id: t.category_id,
        created_at: t.created_at,
        bumped_at: t.bumped_at,
        tags: t.tags.pluck(:name),
        image: t.image_url,
        demand_type: cf[SitetorListing::FIELD_DEMAND_TYPE],
        budget_from: cf[SitetorListing::FIELD_BUDGET_FROM]&.to_i,
        budget_to: cf[SitetorListing::FIELD_BUDGET_TO]&.to_i,
        area_from: cf[SitetorListing::FIELD_AREA_FROM]&.to_f,
        area_to: cf[SitetorListing::FIELD_AREA_TO]&.to_f,
        frontage_from: cf[SitetorListing::FIELD_FRONTAGE_FROM]&.to_f,
        frontage_to: cf[SitetorListing::FIELD_FRONTAGE_TO]&.to_f,
        floor_area_from: cf[SitetorListing::FIELD_FLOOR_AREA_FROM]&.to_f,
        floor_area_to: cf[SitetorListing::FIELD_FLOOR_AREA_TO]&.to_f,
        number_floor: cf[SitetorListing::FIELD_NUMBER_FLOOR]&.to_i,
        property_types: parse_list(cf[SitetorListing::FIELD_DEMAND_PROPERTY_TYPES]),
        provinces: parse_list(cf[SitetorListing::FIELD_DEMAND_PROVINCES]),
        districts: parse_list(cf[SitetorListing::FIELD_DEMAND_DISTRICTS]),
        wards: parse_list(cf[SitetorListing::FIELD_DEMAND_WARDS]),
        streets: parse_list(cf[SitetorListing::FIELD_DEMAND_STREETS]),
        directions: parse_list(cf[SitetorListing::FIELD_DEMAND_DIRECTIONS]),
        positions: parse_list(cf[SitetorListing::FIELD_DEMAND_POSITIONS]),
        purpose: parse_list(cf[SitetorListing::FIELD_DEMAND_PURPOSE]),
        industry: parse_list(cf[SitetorListing::FIELD_DEMAND_INDUSTRY]),
        view: parse_list(cf[SitetorListing::FIELD_DEMAND_VIEW]),
      }
    end

    # Đếm facet cho field JSON array: gom tất cả value trong scope, parse, tally.
    # (dữ liệu nhu cầu ít ~vài trăm topic nên tally ở Ruby rẻ và an toàn hơn unnest SQL)
    def json_facet(topic_ids, field)
      tally = Hash.new(0)
      TopicCustomField.where(name: field, topic_id: topic_ids).pluck(:value).each do |raw|
        parse_list(raw).each { |v| tally[v] += 1 }
      end
      tally.sort_by { |_, c| -c }.first(500).map { |value, count| { value: value, count: count } }
    end

    # Facet cho field string đơn (demand_type)
    def string_facet(topic_ids, field)
      TopicCustomField
        .where(name: field, topic_id: topic_ids)
        .group(:value)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(500)
        .count
        .map { |value, count| { value: value, count: count } }
    end
  end
end
