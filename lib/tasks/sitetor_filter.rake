# frozen_string_literal: true

# Backfill: parse toàn bộ topic cũ trong các category cấu hình.
# Chạy trong container:  rake sitetor_filter:backfill
# Chạy lại an toàn (idempotent) — chỉ ghi đè field khi parse ra giá trị.
desc "Parse giá/mặt tiền/diện tích cho toàn bộ topic BĐS cũ"
task "sitetor_filter:backfill" => :environment do
  cat_ids = SiteSetting.sitetor_filter_categories.split("|").map(&:to_i)
  scope = Topic.where(category_id: cat_ids).where(deleted_at: nil)
  total = scope.count
  done = 0
  hit = 0

  # Dọn giá trị rác từ các lần backfill trước (không phải số, hoặc giá ngoài khoảng hợp lý)
  cleaned = TopicCustomField
    .where(name: [SitetorFilter::FIELD_GIA, SitetorFilter::FIELD_MAT_TIEN, SitetorFilter::FIELD_DIEN_TICH])
    .where.not("value ~ '^\\d+(\\.\\d+)?$'")
    .delete_all
  cleaned += TopicCustomField
    .where(name: SitetorFilter::FIELD_GIA)
    .where(
      "CAST(value AS numeric) < ? OR CAST(value AS numeric) > ?",
      SitetorFilter::Parser::GIA_MIN_HOP_LY,
      SitetorFilter::Parser::GIA_MAX_HOP_LY,
    )
    .delete_all
  puts "Đã dọn #{cleaned} giá trị rác." if cleaned > 0

  puts "Backfill #{total} topics trong categories #{cat_ids.inspect}..."

  scope.find_each do |topic|
    first_post = topic.first_post
    next unless first_post

    parsed = SitetorFilter::Parser.parse(
      "#{topic.title} #{first_post.raw}",
      usd_rate: SiteSetting.sitetor_filter_usd_rate,
    )

    if parsed.values.any?
      topic.custom_fields[SitetorFilter::FIELD_GIA] = parsed[:gia] if parsed[:gia]
      topic.custom_fields[SitetorFilter::FIELD_MAT_TIEN] = parsed[:mat_tien] if parsed[:mat_tien]
      topic.custom_fields[SitetorFilter::FIELD_DIEN_TICH] = parsed[:dien_tich] if parsed[:dien_tich]
      topic.save_custom_fields(true)
      hit += 1
    end

    done += 1
    puts "  #{done}/#{total} (trích được: #{hit})" if (done % 500).zero?
  end

  puts "Xong: #{done} topics, trích được dữ liệu: #{hit} (#{(hit * 100.0 / [total, 1].max).round}%)"
end
