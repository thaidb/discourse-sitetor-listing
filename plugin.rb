# frozen_string_literal: true

# name: discourse-sitetor-filter
# about: Filter BĐS min/max (giá, mặt tiền, diện tích) + bảng so sánh cho Sitetor LMS
# version: 0.1.0
# authors: Sitetor
# url: https://lms.sitetor.com

enabled_site_setting :sitetor_filter_enabled

register_asset "stylesheets/sitetor-filter.scss"

module ::SitetorFilter
  PLUGIN_NAME = "discourse-sitetor-filter"
  FIELD_GIA = "bds_gia"
  FIELD_MAT_TIEN = "bds_mat_tien"
  FIELD_DIEN_TICH = "bds_dien_tich"
end

require_relative "lib/sitetor_filter/parser"

after_initialize do
  module ::SitetorFilter
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace SitetorFilter
    end
  end

  # Custom fields dạng số trên topic
  register_topic_custom_field_type(SitetorFilter::FIELD_GIA, :integer)
  register_topic_custom_field_type(SitetorFilter::FIELD_MAT_TIEN, :float)
  register_topic_custom_field_type(SitetorFilter::FIELD_DIEN_TICH, :float)

  # Tự động parse khi có topic mới / sửa bài đầu trong các category cấu hình
  on(:post_edited) { |post| SitetorFilter::Extract.from_post(post) if post.is_first_post? }
  on(:topic_created) { |topic, _opts, _user| SitetorFilter::Extract.from_post(topic.first_post) if topic.first_post }

  module ::SitetorFilter
    module Extract
      def self.category_ids
        SiteSetting.sitetor_filter_categories.split("|").map(&:to_i)
      end

      def self.from_post(post)
        return unless SiteSetting.sitetor_filter_enabled
        topic = post&.topic
        return unless topic && category_ids.include?(topic.category_id)

        parsed = SitetorFilter::Parser.parse(
          "#{topic.title} #{post.raw}",
          usd_rate: SiteSetting.sitetor_filter_usd_rate,
        )
        topic.custom_fields[FIELD_GIA] = parsed[:gia] if parsed[:gia]
        topic.custom_fields[FIELD_MAT_TIEN] = parsed[:mat_tien] if parsed[:mat_tien]
        topic.custom_fields[FIELD_DIEN_TICH] = parsed[:dien_tich] if parsed[:dien_tich]
        topic.save_custom_fields(true)
      end
    end
  end

  # Trang /listing (Ember) + API filter /listing/filter.json
  require_relative "app/controllers/sitetor_filter/page_controller"
  require_relative "app/controllers/sitetor_filter/filter_controller"

  SitetorFilter::Engine.routes.draw do
    get "/" => "page#index"
    get "/filter" => "filter#index"
  end

  Discourse::Application.routes.append { mount ::SitetorFilter::Engine, at: "/listing" }
end
