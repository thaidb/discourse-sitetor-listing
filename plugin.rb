# frozen_string_literal: true

# name: discourse-sitetor-listing
# about: Filter BĐS đa tiêu chí (giá, mặt tiền, diện tích, loại SP, địa chỉ) + bảng so sánh cho Sitetor LMS
# version: 0.4.0
# authors: Sitetor
# url: https://lms.sitetor.com

enabled_site_setting :sitetor_listing_enabled

register_asset "stylesheets/sitetor-listing.scss"

module ::SitetorListing
  PLUGIN_NAME = "discourse-sitetor-listing"
  FIELD_PRICE = "listing_price"
  FIELD_FRONTAGE = "listing_frontage"
  FIELD_AREA = "listing_area"

  # field dạng chuỗi (parse từ tiêu đề + bài viết bằng catalog địa chỉ CRM)
  FIELD_TYPE = "listing_type"
  FIELD_POSITION = "listing_position"
  FIELD_DIRECTION = "listing_direction"
  FIELD_STREET_NUMBER = "listing_street_number"
  FIELD_STREET = "listing_street"
  FIELD_WARD = "listing_ward"
  FIELD_DISTRICT = "listing_district"
  FIELD_PROVINCE = "listing_province"

  # cờ "chủ topic đã nhập tay" — parser/backfill không được ghi đè
  FIELD_MANUAL = "listing_manual"

  STRING_FIELDS = [
    FIELD_TYPE,
    FIELD_POSITION,
    FIELD_DIRECTION,
    FIELD_STREET_NUMBER,
    FIELD_STREET,
    FIELD_WARD,
    FIELD_DISTRICT,
    FIELD_PROVINCE,
    FIELD_MANUAL,
  ].freeze

  # các field cho phép filter dạng multi-select (param → field)
  MULTI_FILTERS = {
    "type" => FIELD_TYPE,
    "position" => FIELD_POSITION,
    "direction" => FIELD_DIRECTION,
    "street" => FIELD_STREET,
    "ward" => FIELD_WARD,
    "district" => FIELD_DISTRICT,
    "province" => FIELD_PROVINCE,
  }.freeze
end

require_relative "lib/sitetor_listing/parser"
require_relative "lib/sitetor_listing/attributes"
require_relative "lib/sitetor_listing/address_matcher"
require_relative "lib/sitetor_listing/topic_filter"
require_relative "lib/sitetor_listing/seo_slugs"

after_initialize do
  module ::SitetorListing
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace SitetorListing
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
  register_topic_custom_field_type(SitetorListing::FIELD_PRICE, :integer)
  register_topic_custom_field_type(SitetorListing::FIELD_FRONTAGE, :float)
  register_topic_custom_field_type(SitetorListing::FIELD_AREA, :float)
  SitetorListing::STRING_FIELDS.each { |f| register_topic_custom_field_type(f, :string) }

  # Đưa 4 field ra topic list serializer — theme component
  # sitetor-topic-list-columns dùng để vẽ cột MT/Giá/DT/Hướng
  TOPIC_LIST_FIELDS = [
    SitetorListing::FIELD_PRICE,
    SitetorListing::FIELD_FRONTAGE,
    SitetorListing::FIELD_AREA,
    SitetorListing::FIELD_DIRECTION,
  ]
  TOPIC_LIST_FIELDS.each { |f| TopicList.preloaded_custom_fields << f }
  add_to_serializer(:topic_list_item, :listing_price) do
    object.custom_fields[SitetorListing::FIELD_PRICE]
  end
  add_to_serializer(:topic_list_item, :listing_frontage) do
    object.custom_fields[SitetorListing::FIELD_FRONTAGE]
  end
  add_to_serializer(:topic_list_item, :listing_area) do
    object.custom_fields[SitetorListing::FIELD_AREA]
  end
  add_to_serializer(:topic_list_item, :listing_direction) do
    object.custom_fields[SitetorListing::FIELD_DIRECTION]
  end

  # Tự động parse khi có topic mới / sửa bài đầu trong các category cấu hình
  on(:post_edited) { |post| SitetorListing::Extract.from_post(post) if post.is_first_post? }
  on(:topic_created) { |topic, _opts, _user| SitetorListing::Extract.from_post(topic.first_post) if topic.first_post }

  module ::SitetorListing
    module Extract
      # parse cả listing (Bán/Cho thuê) lẫn nhu cầu (Cần mua/Cần thuê) —
      # dữ liệu nhu cầu phục vụ plugin discourse-sitetor-mapping (/mapping)
      def self.category_ids
        ids = (
          SiteSetting.sitetor_listing_categories.split("|") +
            SiteSetting.sitetor_listing_demand_categories.split("|")
        ).map(&:to_i).uniq
        SitetorListing.with_descendants(ids)
      end

      def self.from_post(post)
        return unless SiteSetting.sitetor_listing_enabled
        topic = post&.topic
        return unless topic && category_ids.include?(topic.category_id)

        apply(topic, "#{topic.title} #{post.raw}")
        topic.save_custom_fields(true)
      end

      # gán field từ text — dùng chung cho hook realtime và rake backfill.
      # Topic chủ nhà đã nhập tay (FIELD_MANUAL) thì parser không ghi đè.
      def self.apply(topic, text)
        return false if topic.custom_fields[FIELD_MANUAL] == "true"

        parsed = SitetorListing::Parser.parse(text, usd_rate: SiteSetting.sitetor_listing_usd_rate)
        topic.custom_fields[FIELD_PRICE] = parsed[:price] if parsed[:price]
        topic.custom_fields[FIELD_FRONTAGE] = parsed[:frontage] if parsed[:frontage]
        topic.custom_fields[FIELD_AREA] = parsed[:area] if parsed[:area]

        attrs = SitetorListing::Attributes.extract(text)
        topic.custom_fields[FIELD_TYPE] = attrs[:type] if attrs[:type]
        topic.custom_fields[FIELD_POSITION] = attrs[:position] if attrs[:position]
        topic.custom_fields[FIELD_DIRECTION] = attrs[:direction] if attrs[:direction]

        addr = SitetorListing::AddressMatcher.default.match(text)
        topic.custom_fields[FIELD_STREET_NUMBER] = addr[:street_number] if addr[:street_number]
        topic.custom_fields[FIELD_STREET] = addr[:street] if addr[:street]
        topic.custom_fields[FIELD_WARD] = addr[:ward] if addr[:ward]
        topic.custom_fields[FIELD_DISTRICT] = addr[:district] if addr[:district]
        topic.custom_fields[FIELD_PROVINCE] = addr[:province] if addr[:province]

        parsed.values.any? || attrs.values.any? || addr.values.any?
      end
    end
  end

  # Category type "Listing" trong wizard /new-category/setup
  if respond_to?(:register_category_type)
    require_relative "app/services/sitetor_listing/categories/types/listing"
    reloadable_patch { register_category_type(SitetorListing::Categories::Types::Listing) }
  end

  # Trang /listing (Ember) + API filter/facets
  require_relative "app/controllers/sitetor_listing/page_controller"
  require_relative "app/controllers/sitetor_listing/filter_controller"

  require_relative "app/controllers/sitetor_listing/topic_info_controller"

  SitetorListing::Engine.routes.draw do
    get "/" => "page#index"
    get "/filter" => "filter#index"
    get "/facets" => "filter#facets"
    get "/topic-info" => "topic_info#show"
    put "/topic-info" => "topic_info#update"
    # SEO filter pages: /listing/ban/nha-mat-pho/quan-3/duong-vo-van-tan
    get "/*filters" => "page#seo", format: false
  end

  Discourse::Application.routes.append { mount ::SitetorListing::Engine, at: "/listing" }
end
