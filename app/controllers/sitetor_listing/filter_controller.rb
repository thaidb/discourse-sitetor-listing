# frozen_string_literal: true

module SitetorListing
  class FilterController < ::ApplicationController
    requires_plugin SitetorListing::PLUGIN_NAME

    # GET /listing/filter.json
    # Cách 1 (UI): q, price_min/max, frontage_min/max, area_min/max, loai/quan/... (CSV), category_id, sort, page
    # Cách 2 (SEO): path=ban/nha-mat-pho/quan-3/duong-vo-van-tan — parse thành bộ lọc
    def index
      per = SiteSetting.sitetor_listing_page_size

      if params[:path].present?
        parsed = seo_slugs.parse(params[:path].to_s.split("/").reject(&:blank?), category_slugs: category_slug_map)
        raise Discourse::NotFound unless parsed
        f = filters_from_parsed(parsed)
      else
        parsed = nil
        f = filters_from_params
      end

      result = SitetorListing::TopicFilter.run(f, allowed_ids(f[:category_id]), per: per)

      render json: {
        total: result[:total],
        page: f[:page],
        per_page: per,
        topics: result[:topics].map { |t| SitetorListing::TopicFilter.serialize(t) },
        parsed: parsed && public_parsed(parsed),
        seo_base: seo_base_for(f),
        seo_title: seo_title_for(f),
      }
    end

    # GET /listing/facets.json
    def facets
      base = Topic.visible.listable_topics.where(category_id: allowed_ids(nil))

      district_filter = csv_param(:district)
      cascade = {}
      if district_filter.any?
        cascade_scope = SitetorListing::TopicFilter.by_field(base, SitetorListing::FIELD_DISTRICT, district_filter)
        cascade = {
          ward: facet_counts(cascade_scope, SitetorListing::FIELD_WARD),
          street: facet_counts(cascade_scope, SitetorListing::FIELD_STREET),
        }
      end

      render json: {
        type: facet_counts(base, SitetorListing::FIELD_TYPE),
        position: facet_counts(base, SitetorListing::FIELD_POSITION),
        direction: facet_counts(base, SitetorListing::FIELD_DIRECTION),
        province: facet_counts(base, SitetorListing::FIELD_PROVINCE),
        district: facet_counts(base, SitetorListing::FIELD_DISTRICT),
        ward: cascade[:ward] || [],
        street: cascade[:street] || [],
      }
    end

    private

    def seo_slugs
      SitetorListing::SeoSlugs.default
    end

    def base_category_ids
      SiteSetting.sitetor_listing_categories.split("|").map(&:to_i)
    end

    def base_categories
      @base_categories ||= Category.where(id: base_category_ids)
    end

    def category_slug_map
      base_categories.to_h { |c| [c.slug, c.id] }
    end

    def demand_category_ids
      SiteSetting.sitetor_listing_demand_categories.split("|").map(&:to_i)
    end

    def allowed_ids(category_id)
      ids = base_category_ids
      cid = category_id.to_i
      # Honor an explicit category_id when it belongs to the listing OR demand
      # (mapping) trees; the default (no category_id) stays listing-only.
      if category_id.present? && (base_category_ids + demand_category_ids).include?(cid)
        ids = [cid]
      end
      SitetorListing.with_descendants(ids)
    end

    def csv_param(key)
      params[key].to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def filters_from_params
      {
        q: params[:q],
        price_min: params[:price_min], price_max: params[:price_max],
        frontage_min: params[:frontage_min], frontage_max: params[:frontage_max],
        area_min: params[:area_min], area_max: params[:area_max],
        multi: SitetorListing::MULTI_FILTERS.keys.to_h { |k| [k, csv_param(k)] },
        tags: csv_param(:tags),
        sort: params[:sort],
        page: params[:page].to_i,
        category_id: params[:category_id],
      }
    end

    def filters_from_parsed(parsed)
      multi = {}
      %i[type position direction district ward street].each do |k|
        multi[k.to_s] = parsed[k] ? [parsed[k]] : []
      end
      {
        multi: multi,
        page: parsed[:page].to_i,
        category_id: parsed[:category_id],
      }
    end

    def public_parsed(parsed)
      parsed.slice(:type, :position, :direction, :district, :ward, :street, :category_id).merge(page: parsed[:page].to_i)
    end

    # đường dẫn SEO (không gồm trang) khi bộ lọc quy về được 1 giá trị mỗi chiều
    def seo_singles(f)
      return nil if f[:q].present?
      return nil if %i[price_min price_max frontage_min frontage_max area_min area_max].any? { |k| f[k].present? }

      singles = {}
      (f[:multi] || {}).each do |k, values|
        return nil if values.length > 1
        singles[k.to_sym] = values.first
      end
      return nil if singles.values.all?(&:nil?) && f[:category_id].blank?
      singles
    end

    def seo_base_for(f)
      singles = seo_singles(f)
      return nil unless singles
      cat = f[:category_id].present? ? base_categories.find { |c| c.id == f[:category_id].to_i } : nil
      seo_slugs.build(category_slug: cat&.slug, **singles.slice(:type, :position, :direction, :district, :ward, :street))
    end

    def seo_title_for(f)
      singles = seo_singles(f)
      return nil unless singles
      cat = f[:category_id].present? ? base_categories.find { |c| c.id == f[:category_id].to_i } : nil
      seo_slugs.title(
        category_name: cat&.name,
        page: f[:page].to_i,
        **singles.slice(:type, :position, :direction, :district, :ward, :street, :province),
      )
    end

    def facet_counts(scope, field)
      TopicCustomField
        .where(name: field, topic_id: scope.select(:id))
        .group(:value)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(500)
        .count
        .map { |value, count| { value: value, count: count } }
    end
  end
end
