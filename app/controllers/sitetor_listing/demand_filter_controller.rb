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
      # Khu vực (JSON custom field) đếm bằng json_facet; enum (tag) đếm bằng
      # tag_facet với tập tag của group tương ứng.
      jf = ->(field) { SitetorListing::DemandFilter.json_facet(topic_ids, field) }
      tf = ->(param) { SitetorListing::DemandFilter.tag_facet(topic_ids, SitetorListing::DemandFilter.enum_tag_ids(param)) }

      render json: {
        demand_type: SitetorListing::DemandFilter.string_facet(topic_ids, SitetorListing::FIELD_DEMAND_TYPE),
        property_types: tf.call("property_types"),
        province: jf.call(SitetorListing::FIELD_DEMAND_PROVINCES),
        district: jf.call(SitetorListing::FIELD_DEMAND_DISTRICTS),
        ward: jf.call(SitetorListing::FIELD_DEMAND_WARDS),
        street: jf.call(SitetorListing::FIELD_DEMAND_STREETS),
        direction: tf.call("directions"),
        position: tf.call("positions"),
        purpose: tf.call("purpose"),
        industry: SitetorListing::DemandFilter.tag_facet(topic_ids),
        view: tf.call("view"),
      }
    end

    # GET /listing/demand-matches/:topic_id.json
    # Matching Cung↔Cầu: 1 nhu cầu là BỘ LỌC LƯU SẴN nên tin rao (Cung) khớp =
    # chạy chính TopicFilter trên category listing với tiêu chí của nhu cầu
    # (ngân sách→giá, diện tích, mặt tiền là range; loại BĐS/khu vực/hướng/vị
    # trí là multi IN). mine=true → chỉ tin của người đang đăng nhập (dùng cho
    # nút "Giới thiệu": gợi ý tin phù hợp trong kho của chính họ).
    def matches
      demand = Topic.find_by(id: params[:topic_id].to_i) || raise(Discourse::NotFound)
      guardian.ensure_can_see!(demand)

      per = params[:limit].present? ? params[:limit].to_i.clamp(1, 50) : 20
      f = demand_criteria(demand)
      listing_ids = SitetorListing.with_descendants(
        SiteSetting.sitetor_listing_categories.split("|").map(&:to_i),
      )
      result = SitetorListing::TopicFilter.run(f, listing_ids, per: per)

      topics = result[:topics]
      if ActiveModel::Type::Boolean.new.cast(params[:mine]) && current_user
        topics = topics.where(user_id: current_user.id)
      end

      render json: {
        demand_id: demand.id,
        total: result[:total],
        criteria: public_criteria(f),
        topics: topics.map { |t| SitetorListing::TopicFilter.serialize(t) },
      }
    end

    private

    # tiêu chí lọc listing suy ra từ field demand_* của nhu cầu
    def demand_criteria(demand)
      cf = demand.custom_fields
      pl = ->(field) { SitetorListing::DemandFilter.parse_list(cf[field]) }
      {
        price_min: cf[SitetorListing::FIELD_BUDGET_FROM],
        price_max: cf[SitetorListing::FIELD_BUDGET_TO],
        area_min: cf[SitetorListing::FIELD_AREA_FROM],
        area_max: cf[SitetorListing::FIELD_AREA_TO],
        frontage_min: cf[SitetorListing::FIELD_FRONTAGE_FROM],
        frontage_max: cf[SitetorListing::FIELD_FRONTAGE_TO],
        multi: {
          "type" => pl.call(SitetorListing::FIELD_DEMAND_PROPERTY_TYPES),
          "province" => pl.call(SitetorListing::FIELD_DEMAND_PROVINCES),
          "district" => pl.call(SitetorListing::FIELD_DEMAND_DISTRICTS),
          "ward" => pl.call(SitetorListing::FIELD_DEMAND_WARDS),
          "street" => pl.call(SitetorListing::FIELD_DEMAND_STREETS),
          "direction" => pl.call(SitetorListing::FIELD_DEMAND_DIRECTIONS),
          "position" => pl.call(SitetorListing::FIELD_DEMAND_POSITIONS),
        },
        page: 0,
      }
    end

    def public_criteria(f)
      {
        price_min: f[:price_min]&.to_i,
        price_max: f[:price_max]&.to_i,
        area_min: f[:area_min]&.to_f,
        area_max: f[:area_max]&.to_f,
        frontage_min: f[:frontage_min]&.to_f,
        frontage_max: f[:frontage_max]&.to_f,
        multi: f[:multi].reject { |_, v| v.blank? },
      }
    end

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
        floor_min: params[:floor_min], floor_max: params[:floor_max],
        demand_type: csv_param(:demand_type),
        multi: SitetorListing::DemandFilter::JSON_MULTI.keys.to_h { |k| [k, csv_param(k)] },
        sort: params[:sort],
        page: params[:page].to_i,
        category_id: params[:category_id],
      }
    end
  end
end
