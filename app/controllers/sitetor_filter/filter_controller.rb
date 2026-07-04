# frozen_string_literal: true

module SitetorFilter
  class FilterController < ::ApplicationController
    requires_plugin SitetorFilter::PLUGIN_NAME

    # GET /sitetor-filter/filter.json
    # Params: gia_min, gia_max (VND) | mt_min, mt_max (m) | dt_min, dt_max (m2)
    #         category_id, page
    def index
      page = params[:page].to_i
      per = SiteSetting.sitetor_filter_page_size

      topics = Topic
        .visible
        .listable_topics
        .where(category_id: allowed_category_ids)

      topics = apply_range(topics, SitetorFilter::FIELD_GIA, :gia_min, :gia_max)
      topics = apply_range(topics, SitetorFilter::FIELD_MAT_TIEN, :mt_min, :mt_max)
      topics = apply_range(topics, SitetorFilter::FIELD_DIEN_TICH, :dt_min, :dt_max)

      total = topics.count
      topics = topics.order(bumped_at: :desc).offset(page * per).limit(per)

      render json: {
        total: total,
        page: page,
        topics: topics.map { |t| serialize_topic(t) },
      }
    end

    private

    def allowed_category_ids
      ids = SiteSetting.sitetor_filter_categories.split("|").map(&:to_i)
      if params[:category_id].present? && ids.include?(params[:category_id].to_i)
        [params[:category_id].to_i]
      else
        ids
      end
    end

    def apply_range(scope, field, min_key, max_key)
      min = params[min_key]
      max = params[max_key]
      return scope if min.blank? && max.blank?

      # numeric (không phải bigint) để không tràn với giá trị rác;
      # regex loại giá trị không phải số trước khi CAST.
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

    def serialize_topic(t)
      cf = t.custom_fields
      {
        id: t.id,
        title: t.title,
        slug: t.slug,
        category_id: t.category_id,
        created_at: t.created_at,
        bumped_at: t.bumped_at,
        tags: t.tags.pluck(:name),
        gia: cf[SitetorFilter::FIELD_GIA]&.to_i,
        mat_tien: cf[SitetorFilter::FIELD_MAT_TIEN]&.to_f,
        dien_tich: cf[SitetorFilter::FIELD_DIEN_TICH]&.to_f,
      }
    end
  end
end
