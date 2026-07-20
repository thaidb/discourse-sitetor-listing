# frozen_string_literal: true

module SitetorListing
  # API cho trang /demand (Ember): lọc topic NHU CẦU theo range (ngân sách/diện
  # tích/mặt tiền, khớp overlap) + multi JSON-array (loại BĐS, khu vực, hướng,
  # vị trí, mục đích, ngành, view) + loại giao dịch. Facets đếm theo phần tử.
  class DemandFilterController < ::ApplicationController
    requires_plugin SitetorListing::PLUGIN_NAME

    # GET /listing/demand-filter.json
    def index
      per = SiteSetting.sitetor_listing_page_size
      f = filters_from_params
      result = SitetorListing::DemandFilter.run(f, demand_ids(f[:category_id]), per: per)

      render json: {
        total: result[:total],
        page: f[:page],
        per_page: per,
        topics: result[:topics].map { |t| SitetorListing::DemandFilter.serialize(t) },
      }
    end

    # GET /listing/demand-facets.json
    def facets
      topic_ids = Topic.visible.listable_topics.where(category_id: demand_ids(nil)).select(:id)
      jf = ->(field) { SitetorListing::DemandFilter.json_facet(topic_ids, field) }

      render json: {
        demand_type: SitetorListing::DemandFilter.string_facet(topic_ids, SitetorListing::FIELD_DEMAND_TYPE),
        property_types: jf.call(SitetorListing::FIELD_DEMAND_PROPERTY_TYPES),
        province: jf.call(SitetorListing::FIELD_DEMAND_PROVINCES),
        district: jf.call(SitetorListing::FIELD_DEMAND_DISTRICTS),
        ward: jf.call(SitetorListing::FIELD_DEMAND_WARDS),
        street: jf.call(SitetorListing::FIELD_DEMAND_STREETS),
        direction: jf.call(SitetorListing::FIELD_DEMAND_DIRECTIONS),
        position: jf.call(SitetorListing::FIELD_DEMAND_POSITIONS),
        purpose: jf.call(SitetorListing::FIELD_DEMAND_PURPOSE),
        industry: jf.call(SitetorListing::FIELD_DEMAND_INDUSTRY),
        view: jf.call(SitetorListing::FIELD_DEMAND_VIEW),
      }
    end

    private

    def demand_base_ids
      SiteSetting.sitetor_listing_demand_categories.split("|").map(&:to_i)
    end

    def demand_ids(category_id)
      cid = category_id.to_i
      ids =
        if category_id.present? && demand_base_ids.include?(cid)
          [cid]
        else
          demand_base_ids
        end
      SitetorListing.with_descendants(ids)
    end

    def csv_param(key)
      params[key].to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def filters_from_params
      {
        q: params[:q],
        budget_min: params[:budget_min], budget_max: params[:budget_max],
        area_min: params[:area_min], area_max: params[:area_max],
        frontage_min: params[:frontage_min], frontage_max: params[:frontage_max],
        demand_type: csv_param(:demand_type),
        multi: SitetorListing::DemandFilter::JSON_MULTI.keys.to_h { |k| [k, csv_param(k)] },
        sort: params[:sort],
        page: params[:page].to_i,
        category_id: params[:category_id],
      }
    end
  end
end
