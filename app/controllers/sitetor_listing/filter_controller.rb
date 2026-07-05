# frozen_string_literal: true

module SitetorListing
  class FilterController < ::ApplicationController
    requires_plugin SitetorListing::PLUGIN_NAME

    # GET /listing/filter.json
    # Cách 1 (UI): q, gia_min/max, mt_min/max, dt_min/max, loai/quan/... (CSV), category_id, sort, page
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

      quan_filter = csv_param(:quan)
      cascade = {}
      if quan_filter.any?
        cascade_scope = SitetorListing::TopicFilter.by_field(base, SitetorListing::FIELD_QUAN, quan_filter)
        cascade = {
          phuong: facet_counts(cascade_scope, SitetorListing::FIELD_PHUONG),
          duong: facet_counts(cascade_scope, SitetorListing::FIELD_DUONG),
        }
      end

      render json: {
        loai: facet_counts(base, SitetorListing::FIELD_LOAI),
        vi_tri: facet_counts(base, SitetorListing::FIELD_VI_TRI),
        huong: facet_counts(base, SitetorListing::FIELD_HUONG),
        tinh: facet_counts(base, SitetorListing::FIELD_TINH),
        quan: facet_counts(base, SitetorListing::FIELD_QUAN),
        phuong: cascade[:phuong] || [],
        duong: cascade[:duong] || [],
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

    def allowed_ids(category_id)
      ids = base_category_ids
      ids = [category_id.to_i] if category_id.present? && ids.include?(category_id.to_i)
      SitetorListing.with_descendants(ids)
    end

    def csv_param(key)
      params[key].to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def filters_from_params
      {
        q: params[:q],
        gia_min: params[:gia_min], gia_max: params[:gia_max],
        mt_min: params[:mt_min], mt_max: params[:mt_max],
        dt_min: params[:dt_min], dt_max: params[:dt_max],
        multi: SitetorListing::MULTI_FILTERS.keys.to_h { |k| [k, csv_param(k)] },
        sort: params[:sort],
        page: params[:page].to_i,
        category_id: params[:category_id],
      }
    end

    def filters_from_parsed(parsed)
      multi = {}
      %i[loai vi_tri huong quan phuong duong].each do |k|
        multi[k.to_s] = parsed[k] ? [parsed[k]] : []
      end
      {
        multi: multi,
        page: parsed[:page].to_i,
        category_id: parsed[:category_id],
      }
    end

    def public_parsed(parsed)
      parsed.slice(:loai, :vi_tri, :huong, :quan, :phuong, :duong, :category_id).merge(page: parsed[:page].to_i)
    end

    # đường dẫn SEO (không gồm trang) khi bộ lọc quy về được 1 giá trị mỗi chiều
    def seo_singles(f)
      return nil if f[:q].present?
      return nil if %i[gia_min gia_max mt_min mt_max dt_min dt_max].any? { |k| f[k].present? }

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
      seo_slugs.build(category_slug: cat&.slug, **singles.slice(:loai, :vi_tri, :huong, :quan, :phuong, :duong))
    end

    def seo_title_for(f)
      singles = seo_singles(f)
      return nil unless singles
      cat = f[:category_id].present? ? base_categories.find { |c| c.id == f[:category_id].to_i } : nil
      seo_slugs.title(
        category_name: cat&.name,
        page: f[:page].to_i,
        **singles.slice(:loai, :vi_tri, :huong, :quan, :phuong, :duong),
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
