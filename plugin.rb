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

  # Field NHU CẦU (topic Cần mua/Cần thuê trong sitetor_listing_demand_categories).
  # Nhu cầu là 1 BỘ LỌC LƯU SẴN: range (ngân sách/diện tích/mặt tiền) + multi
  # (nhiều tỉnh/quận/đường, nhiều hướng, nhiều loại) — THUỘC SỞ HỮU demand, KHÔNG
  # dùng chung listing_* (listing_* là giá trị ĐƠN của tin rao, phục vụ filter/facet).
  FIELD_DEMAND_TYPE = "demand_type"
  FIELD_BUDGET_FROM = "budget_from"
  FIELD_BUDGET_TO = "budget_to"
  FIELD_AREA_FROM = "area_from"
  FIELD_AREA_TO = "area_to"
  FIELD_FRONTAGE_FROM = "frontage_from"
  FIELD_FRONTAGE_TO = "frontage_to"
  FIELD_FLOOR_AREA_FROM = "floor_area_from"
  FIELD_FLOOR_AREA_TO = "floor_area_to"
  FIELD_NUMBER_FLOOR = "number_floor"

  # Field phân loại/khu vực của nhu cầu — mỗi field lưu JSON array (multi-value).
  FIELD_DEMAND_PROPERTY_TYPES = "demand_property_types" # loại BĐS (nhiều)
  FIELD_DEMAND_PROVINCES = "demand_provinces"
  FIELD_DEMAND_DISTRICTS = "demand_districts"
  FIELD_DEMAND_WARDS = "demand_wards"
  FIELD_DEMAND_STREETS = "demand_streets"
  FIELD_DEMAND_DIRECTIONS = "demand_directions"
  FIELD_DEMAND_POSITIONS = "demand_positions"
  FIELD_DEMAND_PURPOSE = "demand_purpose"   # JSON array string
  FIELD_DEMAND_INDUSTRY = "demand_industry" # JSON array string
  FIELD_DEMAND_VIEW = "demand_view"         # JSON array string

  FIELD_DEMAND_TITLE = "demand_title"
  FIELD_DEMAND_NOTE = "demand_note"
  FIELD_CUSTOMER_NAME = "customer_name"
  FIELD_CUSTOMER_PHONE = "customer_phone"
  FIELD_CONTACT_EMAIL = "contact_email"

  DEMAND_INTEGER_FIELDS = [FIELD_BUDGET_FROM, FIELD_BUDGET_TO, FIELD_NUMBER_FLOOR].freeze
  DEMAND_FLOAT_FIELDS = [
    FIELD_AREA_FROM,
    FIELD_AREA_TO,
    FIELD_FRONTAGE_FROM,
    FIELD_FRONTAGE_TO,
    FIELD_FLOOR_AREA_FROM,
    FIELD_FLOOR_AREA_TO,
  ].freeze

  # Field lưu JSON array (nhiều giá trị) trên topic nhu cầu
  DEMAND_MULTI_FIELDS = [
    FIELD_DEMAND_PROPERTY_TYPES,
    FIELD_DEMAND_PROVINCES,
    FIELD_DEMAND_DISTRICTS,
    FIELD_DEMAND_WARDS,
    FIELD_DEMAND_STREETS,
    FIELD_DEMAND_DIRECTIONS,
    FIELD_DEMAND_POSITIONS,
    FIELD_DEMAND_PURPOSE,
    FIELD_DEMAND_INDUSTRY,
    FIELD_DEMAND_VIEW,
  ].freeze

  DEMAND_STRING_FIELDS = (
    [FIELD_DEMAND_TYPE] + DEMAND_MULTI_FIELDS +
      [
        FIELD_DEMAND_TITLE,
        FIELD_DEMAND_NOTE,
        FIELD_CUSTOMER_NAME,
        FIELD_CUSTOMER_PHONE,
        FIELD_CONTACT_EMAIL,
      ]
  ).freeze

  # Form "Cập nhật thông tin nhu cầu" (/listing/demand-info): param API → custom field.
  # Param multi dùng số nhiều (provinces/directions...) và ghi field demand_* riêng
  # — KHÔNG còn ghi đè listing_* của tin rao.
  DEMAND_UPDATABLE = {
    "demand_type" => FIELD_DEMAND_TYPE,
    "property_types" => FIELD_DEMAND_PROPERTY_TYPES,
    "provinces" => FIELD_DEMAND_PROVINCES,
    "districts" => FIELD_DEMAND_DISTRICTS,
    "wards" => FIELD_DEMAND_WARDS,
    "streets" => FIELD_DEMAND_STREETS,
    "budget_from" => FIELD_BUDGET_FROM,
    "budget_to" => FIELD_BUDGET_TO,
    "area_from" => FIELD_AREA_FROM,
    "area_to" => FIELD_AREA_TO,
    "frontage_from" => FIELD_FRONTAGE_FROM,
    "frontage_to" => FIELD_FRONTAGE_TO,
    "floor_area_from" => FIELD_FLOOR_AREA_FROM,
    "floor_area_to" => FIELD_FLOOR_AREA_TO,
    "number_floor" => FIELD_NUMBER_FLOOR,
    "purpose" => FIELD_DEMAND_PURPOSE,
    "industry" => FIELD_DEMAND_INDUSTRY,
    "view" => FIELD_DEMAND_VIEW,
    "directions" => FIELD_DEMAND_DIRECTIONS,
    "positions" => FIELD_DEMAND_POSITIONS,
    "title" => FIELD_DEMAND_TITLE,
    "note" => FIELD_DEMAND_NOTE,
    "customer_name" => FIELD_CUSTOMER_NAME,
    "customer_phone" => FIELD_CUSTOMER_PHONE,
    "contact_email" => FIELD_CONTACT_EMAIL,
  }.freeze

  # Param nào của form nhu cầu là multi-value (JSON array) → cast/serialize theo mảng
  DEMAND_MULTI_PARAMS = %w[
    property_types provinces districts wards streets directions positions
    purpose industry view
  ].freeze

  # Danh sách chọn cố định của form nhu cầu — giá trị TRÙNG TÊN TAG trên site
  # (nhóm H Nhu cầu sử dụng / E Hướng / D Vị trí) để đồng bộ tag SEO song song
  DEMAND_TYPES = ["Cần mua", "Cần thuê"].freeze
  DEMAND_PURPOSES = %w[Để-ở Kinh-doanh Đầu-tư].freeze
  DEMAND_DIRECTIONS = %w[Đông Tây Nam Bắc Đông-Bắc Đông-Nam Tây-Bắc Tây-Nam].freeze
  DEMAND_POSITIONS = %w[Hẻm Khu-compound Mặt-tiền Ngõ Nội-bộ].freeze

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
require_relative "lib/sitetor_listing/demand_filter"
require_relative "lib/sitetor_listing/seo_slugs"
require_relative "lib/sitetor_listing/discovery_filters"

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

  # Custom fields nhu cầu (form "Cập nhật thông tin nhu cầu")
  SitetorListing::DEMAND_INTEGER_FIELDS.each { |f| register_topic_custom_field_type(f, :integer) }
  SitetorListing::DEMAND_FLOAT_FIELDS.each { |f| register_topic_custom_field_type(f, :float) }
  SitetorListing::DEMAND_STRING_FIELDS.each { |f| register_topic_custom_field_type(f, :string) }

  # Filter topic list gốc theo query param (thanh filter sau breadcrumb)
  SitetorListing::DiscoveryFilters.register!
  # + matcher BĐS cho ngôn ngữ /filter: price-min:50tr, frontage-min:8, position:hẻm...
  SitetorListing::DiscoveryFilters.register_topics_filter!(self)

  # Ghi các matcher BĐS vào danh sách gợi ý sổ xuống của trang /filter
  # (chức năng lọc và gợi ý là 2 hệ riêng — không đăng ký thì lọc vẫn chạy
  # nhưng user không thấy trong dropdown)
  register_modifier(:topics_filter_options) do |results, _guardian|
    results.concat(
      [
        { name: "price-min:", description: "Giá tối thiểu — 50tr, 5ty (số trần = triệu)", type: "text", priority: 1 },
        { name: "price-max:", description: "Giá tối đa — 100tr, 5ty", type: "text", priority: 1 },
        { name: "frontage-min:", description: "Mặt tiền tối thiểu (m)", type: "text" },
        { name: "frontage-max:", description: "Mặt tiền tối đa (m)", type: "text" },
        { name: "area-min:", description: "Diện tích tối thiểu (m²)", type: "text" },
        { name: "area-max:", description: "Diện tích tối đa (m²)", type: "text" },
        { name: "type:", description: "Loại BĐS — nhiều từ bọc ngoặc kép: type:\"Nhà mặt phố\"", type: "text" },
        { name: "position:", description: "Vị trí: hẻm, mặt tiền, khu compound... (không phân biệt hoa thường)", type: "text" },
        { name: "direction:", description: "Hướng: đông, tây, đông nam...", type: "text" },
      ],
    )
    results
  end

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

  # Field NHU CẦU cho card mặc định của category Mapping (topic list): ngân sách
  # + diện tích (range) + khu vực (JSON array parse sẵn) để theme vẽ trong
  # .topic-card__stats. Chỉ preload đủ field cần cho card, tránh nặng list.
  DEMAND_LIST_FIELDS = [
    SitetorListing::FIELD_DEMAND_TYPE,
    SitetorListing::FIELD_BUDGET_FROM,
    SitetorListing::FIELD_BUDGET_TO,
    SitetorListing::FIELD_AREA_FROM,
    SitetorListing::FIELD_AREA_TO,
    SitetorListing::FIELD_FRONTAGE_FROM,
    SitetorListing::FIELD_DEMAND_PROPERTY_TYPES,
    SitetorListing::FIELD_DEMAND_PROVINCES,
    SitetorListing::FIELD_DEMAND_DISTRICTS,
  ]
  DEMAND_LIST_FIELDS.each { |f| TopicList.preloaded_custom_fields << f }
  add_to_serializer(:topic_list_item, :demand_type) do
    object.custom_fields[SitetorListing::FIELD_DEMAND_TYPE]
  end
  add_to_serializer(:topic_list_item, :demand_budget_from) do
    object.custom_fields[SitetorListing::FIELD_BUDGET_FROM]&.to_i
  end
  add_to_serializer(:topic_list_item, :demand_budget_to) do
    object.custom_fields[SitetorListing::FIELD_BUDGET_TO]&.to_i
  end
  add_to_serializer(:topic_list_item, :demand_area_from) do
    object.custom_fields[SitetorListing::FIELD_AREA_FROM]&.to_f
  end
  add_to_serializer(:topic_list_item, :demand_area_to) do
    object.custom_fields[SitetorListing::FIELD_AREA_TO]&.to_f
  end
  add_to_serializer(:topic_list_item, :demand_frontage_from) do
    object.custom_fields[SitetorListing::FIELD_FRONTAGE_FROM]&.to_f
  end
  add_to_serializer(:topic_list_item, :demand_property_types) do
    SitetorListing::DemandFilter.parse_list(object.custom_fields[SitetorListing::FIELD_DEMAND_PROPERTY_TYPES])
  end
  add_to_serializer(:topic_list_item, :demand_provinces) do
    SitetorListing::DemandFilter.parse_list(object.custom_fields[SitetorListing::FIELD_DEMAND_PROVINCES])
  end
  add_to_serializer(:topic_list_item, :demand_districts) do
    SitetorListing::DemandFilter.parse_list(object.custom_fields[SitetorListing::FIELD_DEMAND_DISTRICTS])
  end

  # Tự động parse khi có topic mới / sửa bài đầu trong các category cấu hình
  on(:post_edited) { |post| SitetorListing::Extract.from_post(post) if post.is_first_post? }
  on(:topic_created) { |topic, _opts, _user| SitetorListing::Extract.from_post(topic.first_post) if topic.first_post }

  module ::SitetorListing
    module Extract
      # Gate hook: parse cả tin rao (Bán/Cho thuê) lẫn nhu cầu (Cần mua/Cần thuê)
      def self.category_ids
        ids = (
          SiteSetting.sitetor_listing_categories.split("|") +
            SiteSetting.sitetor_listing_demand_categories.split("|")
        ).map(&:to_i).uniq
        SitetorListing.with_descendants(ids)
      end

      def self.demand_category_ids
        SitetorListing.with_descendants(
          SiteSetting.sitetor_listing_demand_categories.split("|").map(&:to_i),
        )
      end

      def self.demand?(topic)
        demand_category_ids.include?(topic.category_id)
      end

      def self.from_post(post)
        return unless SiteSetting.sitetor_listing_enabled
        topic = post&.topic
        return unless topic && category_ids.include?(topic.category_id)

        apply(topic, "#{topic.title} #{post.raw}")
        topic.save_custom_fields(true)
      end

      # gán field từ text — dùng chung cho hook realtime và rake backfill.
      # Topic chủ đã nhập tay (FIELD_MANUAL) thì parser không ghi đè.
      # Tin rao → listing_* (giá trị đơn); nhu cầu → demand_* (JSON array).
      def self.apply(topic, text)
        return false if topic.custom_fields[FIELD_MANUAL] == "true"
        demand?(topic) ? apply_demand(topic, text) : apply_listing(topic, text)
      end

      def self.apply_listing(topic, text)
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

      # Nhu cầu: auto-seed loại BĐS + khu vực thành mảng 1 phần tử (để /mapping
      # có dữ liệu ngay). Chỉ set field còn trống — không thu hẹp list chủ đã chọn.
      # Giá/mặt tiền/diện tích của nhu cầu là RANGE nên không suy từ 1 giá trị parse.
      def self.apply_demand(topic, text)
        attrs = SitetorListing::Attributes.extract(text)
        addr = SitetorListing::AddressMatcher.default.match(text)
        seeds = {
          FIELD_DEMAND_PROPERTY_TYPES => attrs[:type],
          FIELD_DEMAND_STREETS => addr[:street],
          FIELD_DEMAND_WARDS => addr[:ward],
          FIELD_DEMAND_DISTRICTS => addr[:district],
          FIELD_DEMAND_PROVINCES => addr[:province],
        }
        touched = false
        seeds.each do |field, value|
          next if value.blank? || topic.custom_fields[field].present?
          topic.custom_fields[field] = [value].to_json
          touched = true
        end
        touched
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
  require_relative "app/controllers/sitetor_listing/demand_info_controller"
  require_relative "app/controllers/sitetor_listing/demand_filter_controller"

  SitetorListing::Engine.routes.draw do
    get "/" => "page#index"
    get "/filter" => "filter#index"
    get "/facets" => "filter#facets"
    get "/topic-info" => "topic_info#show"
    put "/topic-info" => "topic_info#update"
    get "/demand-info/:topic_id" => "demand_info#show"
    post "/demand-info/:topic_id" => "demand_info#update"
    # Trang /demand (Cầu): API lọc nhu cầu + facets
    get "/demand-filter" => "demand_filter#index"
    get "/demand-facets" => "demand_filter#facets"
    # Matching Cung↔Cầu: tin rao khớp 1 nhu cầu (mine=1 → tin của chính user)
    get "/demand-matches/:topic_id" => "demand_filter#matches"
    # SEO filter pages: /listing/ban/nha-mat-pho/quan-3/duong-vo-van-tan
    get "/*filters" => "page#seo", format: false
  end

  # /listing = trang Cung (tin rao). /demand = trang Cầu (nhu cầu) — full-page
  # load render app shell để Ember boot route "demand". Không đụng /mapping của
  # plugin cũ (cutover về sau ở Phase 4).
  Discourse::Application.routes.append do
    mount ::SitetorListing::Engine, at: "/listing"
    get "/demand" => "sitetor_listing/page#demand_index"
  end
end
