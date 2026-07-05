# frozen_string_literal: true

# Query lọc topic dùng chung cho FilterController (JSON) và PageController#seo
# (HTML cho crawler). Nhận hash filter đã chuẩn hoá, trả {total:, topics:}.
module SitetorListing
  module TopicFilter
    SORTS = {
      "price_asc" => [SitetorListing::FIELD_GIA, "ASC"],
      "price_desc" => [SitetorListing::FIELD_GIA, "DESC"],
      "area_desc" => [SitetorListing::FIELD_DIEN_TICH, "DESC"],
    }.freeze

    module_function

    # f: { q:, gia_min:, gia_max:, mt_min:, mt_max:, dt_min:, dt_max:,
    #      multi: {"loai"=>["Nhà mặt phố"], ...}, sort:, page: }
    def run(f, category_ids, per:)
      scope = Topic.visible.listable_topics.where(category_id: category_ids)

      if f[:q].present?
        scope = scope.where("topics.title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(f[:q])}%")
      end

      scope = range(scope, SitetorListing::FIELD_GIA, f[:gia_min], f[:gia_max])
      scope = range(scope, SitetorListing::FIELD_MAT_TIEN, f[:mt_min], f[:mt_max])
      scope = range(scope, SitetorListing::FIELD_DIEN_TICH, f[:dt_min], f[:dt_max])

      (f[:multi] || {}).each do |param, values|
        field = SitetorListing::MULTI_FILTERS[param]
        scope = by_field(scope, field, values) if field && values.present?
      end

      total = scope.count
      page = f[:page].to_i
      topics = sort(scope, f[:sort]).offset(page * per).limit(per)
      { total: total, topics: topics }
    end

    def by_field(scope, field, values)
      scope.joins(<<~SQL).where("mf_#{field}.value IN (?)", values)
        INNER JOIN topic_custom_fields mf_#{field}
          ON mf_#{field}.topic_id = topics.id
          AND mf_#{field}.name = '#{field}'
      SQL
    end

    def range(scope, field, min, max)
      return scope if min.blank? && max.blank?

      scope = scope.joins(<<~SQL)
        INNER JOIN topic_custom_fields tcf_#{field}
          ON tcf_#{field}.topic_id = topics.id
          AND tcf_#{field}.name = '#{field}'
          AND tcf_#{field}.value ~ '^\\d+(\\.\\d+)?$'
      SQL
      scope = scope.where("CAST(tcf_#{field}.value AS numeric) >= ?", min.to_f) if min.present?
      scope = scope.where("CAST(tcf_#{field}.value AS numeric) <= ?", max.to_f) if max.present?
      scope
    end

    def sort(scope, key)
      field, dir = SORTS[key.to_s]
      return scope.order(bumped_at: :desc) unless field

      scope
        .joins(<<~SQL)
          LEFT JOIN topic_custom_fields sort_#{field}
            ON sort_#{field}.topic_id = topics.id
            AND sort_#{field}.name = '#{field}'
            AND sort_#{field}.value ~ '^\\d+(\\.\\d+)?$'
        SQL
        .order(Arel.sql("CAST(sort_#{field}.value AS numeric) #{dir} NULLS LAST, topics.bumped_at DESC"))
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
        gia: cf[SitetorListing::FIELD_GIA]&.to_i,
        mat_tien: cf[SitetorListing::FIELD_MAT_TIEN]&.to_f,
        dien_tich: cf[SitetorListing::FIELD_DIEN_TICH]&.to_f,
        loai: cf[SitetorListing::FIELD_LOAI],
        vi_tri: cf[SitetorListing::FIELD_VI_TRI],
        huong: cf[SitetorListing::FIELD_HUONG],
        so_nha: cf[SitetorListing::FIELD_SO_NHA],
        duong: cf[SitetorListing::FIELD_DUONG],
        phuong: cf[SitetorListing::FIELD_PHUONG],
        quan: cf[SitetorListing::FIELD_QUAN],
        tinh: cf[SitetorListing::FIELD_TINH],
      }
    end
  end
end
