# frozen_string_literal: true

# name: discourse-sitetor-filter
# about: Filter BĐS đa tiêu chí (giá, mặt tiền, diện tích, loại SP, địa chỉ) + bảng so sánh cho Sitetor LMS
# version: 0.2.0
# authors: Sitetor
# url: https://lms.sitetor.com

enabled_site_setting :sitetor_filter_enabled

register_asset "stylesheets/sitetor-filter.scss"

module ::SitetorFilter
  PLUGIN_NAME = "discourse-sitetor-filter"
  FIELD_GIA = "bds_gia"
  FIELD_MAT_TIEN = "bds_mat_tien"
  FIELD_DIEN_TICH = "bds_dien_tich"

  # field dạng chuỗi (parse từ tiêu đề + bài viết bằng catalog địa chỉ CRM)
  FIELD_LOAI = "bds_loai"
  FIELD_VI_TRI = "bds_vi_tri"
  FIELD_HUONG = "bds_huong"
  FIELD_SO_NHA = "bds_so_nha"
  FIELD_DUONG = "bds_duong"
  FIELD_PHUONG = "bds_phuong"
  FIELD_QUAN = "bds_quan"
  FIELD_TINH = "bds_tinh"

  STRING_FIELDS = [
    FIELD_LOAI,
    FIELD_VI_TRI,
    FIELD_HUONG,
    FIELD_SO_NHA,
    FIELD_DUONG,
    FIELD_PHUONG,
    FIELD_QUAN,
    FIELD_TINH,
  ].freeze

  # các field cho phép filter dạng multi-select (param → field)
  MULTI_FILTERS = {
    "loai" => FIELD_LOAI,
    "vi_tri" => FIELD_VI_TRI,
    "huong" => FIELD_HUONG,
    "duong" => FIELD_DUONG,
    "phuong" => FIELD_PHUONG,
    "quan" => FIELD_QUAN,
    "tinh" => FIELD_TINH,
  }.freeze
end

require_relative "lib/sitetor_filter/parser"
require_relative "lib/sitetor_filter/attributes"
require_relative "lib/sitetor_filter/address_matcher"
require_relative "lib/sitetor_filter/topic_filter"
require_relative "lib/sitetor_filter/seo_slugs"

after_initialize do
  module ::SitetorFilter
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace SitetorFilter
    end

    # Mở rộng danh sách category gồm cả sub + sub-sub (hỗ trợ gộp về
    # 1 category cha Listing/Mapping với cây con bên trong)
    def self.with_descendants(ids)
      children = Category.where(parent_category_id: ids).pluck(:id)
      grandchildren = Category.where(parent_category_id: children).pluck(:id)
      (ids + children + grandchildren).uniq
    end
  end

  # Custom fields dạng số trên topic
  register_topic_custom_field_type(SitetorFilter::FIELD_GIA, :integer)
  register_topic_custom_field_type(SitetorFilter::FIELD_MAT_TIEN, :float)
  register_topic_custom_field_type(SitetorFilter::FIELD_DIEN_TICH, :float)
  SitetorFilter::STRING_FIELDS.each { |f| register_topic_custom_field_type(f, :string) }

  # Tự động parse khi có topic mới / sửa bài đầu trong các category cấu hình
  on(:post_edited) { |post| SitetorFilter::Extract.from_post(post) if post.is_first_post? }
  on(:topic_created) { |topic, _opts, _user| SitetorFilter::Extract.from_post(topic.first_post) if topic.first_post }

  module ::SitetorFilter
    module Extract
      # parse cả listing (Bán/Cho thuê) lẫn nhu cầu (Cần mua/Cần thuê) —
      # dữ liệu nhu cầu phục vụ plugin discourse-sitetor-mapping (/mapping)
      def self.category_ids
        ids = (
          SiteSetting.sitetor_filter_categories.split("|") +
            SiteSetting.sitetor_filter_demand_categories.split("|")
        ).map(&:to_i).uniq
        SitetorFilter.with_descendants(ids)
      end

      def self.from_post(post)
        return unless SiteSetting.sitetor_filter_enabled
        topic = post&.topic
        return unless topic && category_ids.include?(topic.category_id)

        apply(topic, "#{topic.title} #{post.raw}")
        topic.save_custom_fields(true)
      end

      # gán field từ text — dùng chung cho hook realtime và rake backfill
      def self.apply(topic, text)
        parsed = SitetorFilter::Parser.parse(text, usd_rate: SiteSetting.sitetor_filter_usd_rate)
        topic.custom_fields[FIELD_GIA] = parsed[:gia] if parsed[:gia]
        topic.custom_fields[FIELD_MAT_TIEN] = parsed[:mat_tien] if parsed[:mat_tien]
        topic.custom_fields[FIELD_DIEN_TICH] = parsed[:dien_tich] if parsed[:dien_tich]

        attrs = SitetorFilter::Attributes.extract(text)
        topic.custom_fields[FIELD_LOAI] = attrs[:loai] if attrs[:loai]
        topic.custom_fields[FIELD_VI_TRI] = attrs[:vi_tri] if attrs[:vi_tri]
        topic.custom_fields[FIELD_HUONG] = attrs[:huong] if attrs[:huong]

        addr = SitetorFilter::AddressMatcher.default.match(text)
        topic.custom_fields[FIELD_SO_NHA] = addr[:so_nha] if addr[:so_nha]
        topic.custom_fields[FIELD_DUONG] = addr[:duong] if addr[:duong]
        topic.custom_fields[FIELD_PHUONG] = addr[:phuong] if addr[:phuong]
        topic.custom_fields[FIELD_QUAN] = addr[:quan] if addr[:quan]
        topic.custom_fields[FIELD_TINH] = addr[:tinh] if addr[:tinh]

        parsed.values.any? || attrs.values.any? || addr.values.any?
      end
    end
  end

  # Trang /listing (Ember) + API filter/facets
  require_relative "app/controllers/sitetor_filter/page_controller"
  require_relative "app/controllers/sitetor_filter/filter_controller"

  SitetorFilter::Engine.routes.draw do
    get "/" => "page#index"
    get "/filter" => "filter#index"
    get "/facets" => "filter#facets"
    # SEO filter pages: /listing/ban/nha-mat-pho/quan-3/duong-vo-van-tan
    get "/*filters" => "page#seo", format: false
  end

  Discourse::Application.routes.append { mount ::SitetorFilter::Engine, at: "/listing" }
end
