# frozen_string_literal: true

module SitetorFilter
  # /listing (trang Ember) + /listing/<slug-filter> (SEO filter pages).
  # Bot (Googlebot...) nhận HTML thật: title/H1/meta/canonical + danh sách tin;
  # người thật nhận app shell để Ember render trang filter với bộ lọc gắn sẵn.
  class PageController < ::ApplicationController
    requires_plugin SitetorFilter::PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      render "default/empty"
    end

    def seo
      segments = params[:filters].to_s.split("/").reject(&:blank?)
      parsed = SitetorFilter::SeoSlugs.default.parse(segments, category_slugs: category_slug_map)
      raise Discourse::NotFound unless parsed

      if use_crawler_layout?
        render html: crawler_html(parsed).html_safe, layout: false
      else
        render "default/empty"
      end
    end

    private

    def base_categories
      @base_categories ||=
        Category.where(id: SiteSetting.sitetor_filter_categories.split("|").map(&:to_i))
    end

    def category_slug_map
      base_categories.to_h { |c| [c.slug, c.id] }
    end

    def crawler_html(parsed)
      slugs = SitetorFilter::SeoSlugs.default
      per = SiteSetting.sitetor_filter_page_size
      page = parsed[:page].to_i
      cat = parsed[:category_id] && base_categories.find { |c| c.id == parsed[:category_id] }

      multi = {}
      %i[loai vi_tri huong quan phuong duong].each { |k| multi[k.to_s] = parsed[k] ? [parsed[k]] : [] }
      ids = SitetorFilter.with_descendants(cat ? [cat.id] : base_categories.map(&:id))
      result = SitetorFilter::TopicFilter.run({ multi: multi, page: page }, ids, per: per)

      title_core = slugs.title(
        category_name: cat&.name, page: page,
        **parsed.slice(:loai, :vi_tri, :huong, :quan, :phuong, :duong),
      )
      base_path = slugs.build(
        category_slug: cat&.slug,
        **parsed.slice(:loai, :vi_tri, :huong, :quan, :phuong, :duong),
      )
      canonical = "#{Discourse.base_url}/listing/#{base_path}#{page > 0 ? "/trang-#{page + 1}" : ""}"
      e = ->(s) { ERB::Util.html_escape(s.to_s) }

      items = result[:topics].map do |t|
        row = SitetorFilter::TopicFilter.serialize(t)
        gia = row[:gia] ? (row[:gia] >= 1e9 ? "#{(row[:gia] / 1e9.to_f).round(2)} tỷ" : "#{(row[:gia] / 1e6.to_f).round(1)} triệu") : nil
        meta = [row[:loai], row[:duong] && "đường #{row[:duong]}", row[:quan], gia, row[:dien_tich] && "#{row[:dien_tich]} m²"].compact.join(" · ")
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
