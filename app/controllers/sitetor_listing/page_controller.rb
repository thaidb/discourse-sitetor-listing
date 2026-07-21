# frozen_string_literal: true

module SitetorListing
  # /listing (trang Ember) + /listing/<slug-filter> (SEO filter pages).
  # Bot (Googlebot...) nhận HTML thật: title/H1/meta/canonical + danh sách tin;
  # người thật nhận app shell để Ember render trang filter với bộ lọc gắn sẵn.
  class PageController < ::ApplicationController
    requires_plugin SitetorListing::PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      render "default/empty"
    end

    # /demand — full page load: render app shell rỗng để Ember boot; route
    # "demand" phía client đảm nhận phần còn lại (danh sách + bộ lọc nhu cầu).
    def demand_index
      render "default/empty"
    end

    def seo
      segments = params[:filters].to_s.split("/").reject(&:blank?)
      parsed = SitetorListing::SeoSlugs.default.parse(segments, category_slugs: category_slug_map)
      raise Discourse::NotFound unless parsed

      if use_crawler_layout?
        render html: crawler_html(parsed).html_safe, layout: false
      else
        render "default/empty"
      end
    end

    # /demand/<slug> — landing page 1 ngành nghề (vd /demand/thoi-trang). Bot nhận
    # HTML thật (title/H1/meta/canonical + danh sách nhu cầu lọc theo tag ngành);
    # người thật nhận app shell → route "demand-tag" gắn filter industry theo slug.
    def demand_tag
      name = SitetorListing::DemandFilter.industry_name_for_slug(params[:slug])
      raise Discourse::NotFound unless name

      if use_crawler_layout?
        render html: demand_crawler_html(name).html_safe, layout: false
      else
        render "default/empty"
      end
    end

    private

    def demand_crawler_html(name)
      per = SiteSetting.sitetor_listing_page_size
      ids = SitetorListing.with_descendants(
        SiteSetting.sitetor_listing_demand_categories.split("|").map(&:to_i),
      )
      result = SitetorListing::DemandFilter.run({ multi: { "industry" => [name] }, page: 0 }, ids, per: per)

      pretty = name.tr("-", " ")
      title = "Nhu cầu thuê & mua mặt bằng #{pretty}"
      canonical = "#{Discourse.base_url}/demand/#{SitetorListing::DemandFilter.slug_for(name)}"
      e = ->(s) { ERB::Util.html_escape(s.to_s) }

      items = result[:topics].map do |t|
        row = SitetorListing::DemandFilter.serialize(t)
        budget = row[:budget_from] || row[:budget_to]
        price = budget ? (budget >= 1e9 ? "#{(budget / 1e9.to_f).round(2)} tỷ" : "#{(budget / 1e6.to_f).round(1)} triệu") : nil
        region = (row[:districts] + row[:provinces]).uniq.join(" · ")
        meta = [row[:demand_type], region.presence, price, row[:area_from] && "#{row[:area_from]} m²"].compact.join(" · ")
        "<li><a href=\"#{Discourse.base_url}/t/#{e.call(t.slug)}/#{t.id}\">#{e.call(t.title)}</a>#{meta.present? ? " — #{e.call(meta)}" : ""}</li>"
      end

      description = "#{title} — #{result[:total]} nhu cầu tìm thuê/mua mặt bằng #{pretty} mới nhất trên #{SiteSetting.title}."

      <<~HTML
        <!DOCTYPE html>
        <html lang="vi">
        <head>
          <meta charset="utf-8">
          <title>#{e.call(title)} | #{e.call(SiteSetting.title)}</title>
          <meta name="description" content="#{e.call(description)}">
          <link rel="canonical" href="#{e.call(canonical)}">
          <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body>
          <h1>#{e.call(title)}</h1>
          <p>#{e.call(result[:total])} nhu cầu</p>
          <ul>
            #{items.join("\n")}
          </ul>
          <p><a href="#{Discourse.base_url}/demand">Tất cả nhu cầu</a></p>
        </body>
        </html>
      HTML
    end

    def base_categories
      @base_categories ||=
        Category.where(id: SiteSetting.sitetor_listing_categories.split("|").map(&:to_i))
    end

    def category_slug_map
      base_categories.to_h { |c| [c.slug, c.id] }
    end

    def crawler_html(parsed)
      slugs = SitetorListing::SeoSlugs.default
      per = SiteSetting.sitetor_listing_page_size
      page = parsed[:page].to_i
      cat = parsed[:category_id] && base_categories.find { |c| c.id == parsed[:category_id] }

      multi = {}
      %i[type position direction district ward street].each { |k| multi[k.to_s] = parsed[k] ? [parsed[k]] : [] }
      ids = SitetorListing.with_descendants(cat ? [cat.id] : base_categories.map(&:id))
      result = SitetorListing::TopicFilter.run({ multi: multi, page: page }, ids, per: per)

      title_core = slugs.title(
        category_name: cat&.name, page: page,
        **parsed.slice(:type, :position, :direction, :district, :ward, :street),
      )
      base_path = slugs.build(
        category_slug: cat&.slug,
        **parsed.slice(:type, :position, :direction, :district, :ward, :street),
      )
      canonical = "#{Discourse.base_url}/listing/#{base_path}#{page > 0 ? "/trang-#{page + 1}" : ""}"
      e = ->(s) { ERB::Util.html_escape(s.to_s) }

      items = result[:topics].map do |t|
        row = SitetorListing::TopicFilter.serialize(t)
        price = row[:price] ? (row[:price] >= 1e9 ? "#{(row[:price] / 1e9.to_f).round(2)} tỷ" : "#{(row[:price] / 1e6.to_f).round(1)} triệu") : nil
        meta = [row[:type], row[:street] && "đường #{row[:street]}", row[:district], price, row[:area] && "#{row[:area]} m²"].compact.join(" · ")
        "<li><a href=\"#{Discourse.base_url}/t/#{e.call(t.slug)}/#{t.id}\">#{e.call(t.title)}</a>#{meta.present? ? " — #{e.call(meta)}" : ""}</li>"
      end

      total_pages = [(result[:total].to_f / per).ceil, 1].max
      nav = []
      nav << "<a rel=\"prev\" href=\"#{Discourse.base_url}/listing/#{base_path}#{page > 1 ? "/trang-#{page}" : ""}\">‹ Trang trước</a>" if page > 0
      nav << "<a rel=\"next\" href=\"#{Discourse.base_url}/listing/#{base_path}/trang-#{page + 2}\">Trang sau ›</a>" if page + 1 < total_pages

      description = "#{title_core} — #{result[:total]} tin đăng, cập nhật mới nhất trên #{SiteSetting.title}."

      <<~HTML
        <!DOCTYPE html>
        <html lang="vi">
        <head>
          <meta charset="utf-8">
          <title>#{e.call(title_core)} | #{e.call(SiteSetting.title)}</title>
          <meta name="description" content="#{e.call(description)}">
          <link rel="canonical" href="#{e.call(canonical)}">
          <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body>
          <h1>#{e.call(title_core)}</h1>
          <p>#{e.call(result[:total])} tin đăng#{page > 0 ? " — trang #{page + 1}/#{total_pages}" : ""}</p>
          <ul>
            #{items.join("\n")}
          </ul>
          <nav>#{nav.join(" | ")}</nav>
          <p><a href="#{Discourse.base_url}/listing">Bộ lọc đầy đủ</a></p>
        </body>
        </html>
      HTML
    end
  end
end
