# frozen_string_literal: true

# name: discourse-sitetor-bds
# about: Filter BĐS min/max (giá, mặt tiền, diện tích) + bảng so sánh cho Sitetor LMS
# version: 0.1.0
# authors: Sitetor
# url: https://lms.sitetor.com

enabled_site_setting :sitetor_bds_enabled

register_asset "stylesheets/sitetor-bds.scss"

module ::SitetorBds
  PLUGIN_NAME = "discourse-sitetor-bds"
  FIELD_GIA = "bds_gia"
  FIELD_MAT_TIEN = "bds_mat_tien"
  FIELD_DIEN_TICH = "bds_dien_tich"
end

require_relative "lib/sitetor_bds/parser"

after_initialize do
  module ::SitetorBds
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace SitetorBds
    end
  end

  # Custom fields dạng số trên topic
  register_topic_custom_field_type(SitetorBds::FIELD_GIA, :integer)
  register_topic_custom_field_type(SitetorBds::FIELD_MAT_TIEN, :float)
  register_topic_custom_field_type(SitetorBds::FIELD_DIEN_TICH, :float)

  # Tự động parse khi có topic mới / sửa bài đầu trong các category cấu hình
  on(:post_edited) { |post| SitetorBds::Extract.from_post(post) if post.is_first_post? }
  on(:topic_created) { |topic, _opts, _user| SitetorBds::Extract.from_post(topic.first_post) if topic.first_post }

  module ::SitetorBds
    module Extract
      def self.category_ids
        SiteSetting.sitetor_bds_categories.split("|").map(&:to_i)
      end

      def self.from_post(post)
        return unless SiteSetting.sitetor_bds_enabled
        topic = post&.topic
        return unless topic && category_ids.include?(topic.category_id)

        parsed = SitetorBds::Parser.parse(
          "#{topic.title} #{post.raw}",
          usd_rate: SiteSetting.sitetor_bds_usd_rate,
        )
        topic.custom_fields[FIELD_GIA] = parsed[:gia] if parsed[:gia]
        topic.custom_fields[FIELD_MAT_TIEN] = parsed[:mat_tien] if parsed[:mat_tien]
        topic.custom_fields[FIELD_DIEN_TICH] = parsed[:dien_tich] if parsed[:dien_tich]
        topic.save_custom_fields(true)
      end
    end
  end

  # Trang /bds (Ember) + API filter /bds/filter.json
  require_relative "app/controllers/sitetor_bds/page_controller"
  require_relative "app/controllers/sitetor_bds/filter_controller"

  SitetorBds::Engine.routes.draw do
    get "/" => "page#index"
    get "/filter" => "filter#index"
  end

  Discourse::Application.routes.append { mount ::SitetorBds::Engine, at: "/bds" }
end
