# frozen_string_literal: true

module SitetorListing
  # Chủ topic (hoặc staff) nhập/sửa thông tin NHU CẦU (Cần mua/Cần thuê):
  # ngân sách, diện tích, mặt tiền, khu vực, mục đích, ngành nghề, thông tin khách.
  # Nhu cầu là 1 BỘ LỌC LƯU SẴN — mọi tiêu chí phân loại/khu vực là multi-value
  # (JSON array) và lưu ở field demand_* riêng, KHÔNG dùng chung listing_* của tin rao.
  # Custom field là NGUỒN CHUẨN; tag SEO được đồng bộ song song từ purpose/industry/
  # hướng/vị trí (giá trị == tên tag). Sau khi nhập tay, cờ listing_manual=true chặn
  # parser ghi đè.
  class DemandInfoController < ::ApplicationController
    requires_plugin SitetorListing::PLUGIN_NAME
    before_action :ensure_logged_in, only: [:update]

    INTEGER_PARAMS = %w[budget_from budget_to number_floor].freeze
    FLOAT_PARAMS = %w[area_from area_to frontage_from frontage_to floor_area_from floor_area_to].freeze
    MULTI_PARAMS = SitetorListing::DEMAND_MULTI_PARAMS
    # Chiều enum (tập đóng) lưu bằng TAG, KHÔNG custom field: đọc/ghi qua tag group
    # (DemandFilter.enum_tag_names). Còn lại provinces/districts/wards/streets là khu
    # vực free-text (JSON custom field).
    ENUM_TAG_PARAMS = %w[property_types positions directions view purpose industry].freeze
    # demand_type là single-select (loại giao dịch)
    SELECT_PARAMS = { "demand_type" => SitetorListing::DEMAND_TYPES }.freeze

    TEXT_MAX = 120
    NOTE_MAX = 2000
    MULTI_MAX = 30

    # GET /listing/demand-info/:topic_id
    def show
      topic = find_topic
      guardian.ensure_can_see!(topic)
      render json: info_for(topic)
    end

    # POST /listing/demand-info/:topic_id — blank = xóa giá trị field đó
    def update
      topic = find_topic
      guardian.ensure_can_edit!(topic)

      # Field params (range/khu vực/liên hệ/demand_type) → custom field.
      SitetorListing::DEMAND_UPDATABLE.each do |param, field|
        next if ENUM_TAG_PARAMS.include?(param)
        next unless params.key?(param)
        write_field(topic, field, cast_param(param, params[param]))
      end

      topic.custom_fields[SitetorListing::FIELD_MANUAL] = "true"
      topic.save_custom_fields(true)

      # Enum params → TAG (thay thế trong các nhóm được submit, giữ tag ngoài nhóm).
      write_enum_tags(topic)

      render json: info_for(topic)
    end

    private

    def find_topic
      Topic.find_by(id: params[:topic_id].to_i) || raise(Discourse::NotFound)
    end

    def write_field(topic, field, value)
      if value.nil?
        topic.custom_fields.delete(field)
      else
        topic.custom_fields[field] = value
      end
    end

    def cast_param(param, raw)
      if INTEGER_PARAMS.include?(param)
        value = raw.presence&.to_f
        value && value > 0 ? value.round : nil
      elsif FLOAT_PARAMS.include?(param)
        value = raw.presence&.to_f
        value && value > 0 ? value : nil
      elsif MULTI_PARAMS.include?(param)
        # còn lại chỉ là khu vực (provinces/districts/wards/streets) — free-text.
        list =
          parse_multi(raw)
            .map { |v| v.to_s.strip.slice(0, TEXT_MAX) }
            .reject(&:blank?)
            .uniq
            .first(MULTI_MAX)
        list.present? ? list.to_json : nil
      elsif (allowed = SELECT_PARAMS[param])
        value = raw.presence
        allowed.include?(value) ? value : nil
      else
        raw.presence&.slice(0, param == "note" ? NOTE_MAX : TEXT_MAX)
      end
    end

    # multi field nhận JSON array string từ client (lưu nguyên dạng đó vào custom field)
    def parse_multi(raw)
      return raw if raw.is_a?(Array)
      parsed = JSON.parse(raw.to_s)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    # Ghi chiều enum bằng TAG (nguồn chân lý). Ngữ nghĩa "thay-thế-trong-nhóm":
    # với mỗi nhóm enum được submit, bỏ hết tag cũ của nhóm đó rồi đặt đúng lựa
    # chọn mới; tag ngoài các nhóm submit (nhóm khác, tag tự do) GIỮ NGUYÊN.
    # Quy tắc mặc định: chọn "Nhà-mặt-tiền" ⇒ kèm Vị trí "Mặt-tiền".
    def write_enum_tags(topic)
      managed = ENUM_TAG_PARAMS.select { |p| params.key?(p) }
      return if managed.empty?

      chosen = []
      vocab = []
      managed.each do |param|
        names = SitetorListing::DemandFilter.enum_tag_names(param)
        vocab |= names
        sel = parse_multi(params[param]).map { |v| v.to_s.strip }.reject(&:blank?)
        chosen |= (sel & names).first(MULTI_MAX) # chỉ nhận tag hợp lệ trong group
      end

      if chosen.include?("Nhà-mặt-tiền") && !chosen.include?("Mặt-tiền") &&
           SitetorListing::DemandFilter.enum_tag_names("positions").include?("Mặt-tiền")
        chosen << "Mặt-tiền"
      end

      keep = topic.tags.map(&:name) - vocab # tag ngoài các nhóm submit
      DiscourseTagging.tag_topic_by_names(
        topic,
        Guardian.new(Discourse.system_user),
        (keep + chosen).uniq,
        append: false, # thay toàn bộ = keep + chosen (đã gồm mọi tag cần giữ)
      )
    end

    def info_for(topic)
      cf = topic.custom_fields
      tnames = topic.tags.map(&:name)
      out = {
        topic_id: topic.id,
        can_edit: guardian.can_edit?(topic),
        manual: cf[SitetorListing::FIELD_MANUAL] == "true",
      }
      SitetorListing::DEMAND_UPDATABLE.each do |param, field|
        out[param] =
          if ENUM_TAG_PARAMS.include?(param)
            tnames & SitetorListing::DemandFilter.enum_tag_names(param)
          elsif MULTI_PARAMS.include?(param)
            parse_multi(cf[field])
          elsif INTEGER_PARAMS.include?(param)
            cf[field]&.to_i
          elsif FLOAT_PARAMS.include?(param)
            cf[field]&.to_f
          else
            cf[field]
          end
      end
      out
    end
  end
end
