# frozen_string_literal: true

# Backfill: parse toàn bộ topic cũ trong các category cấu hình.
# Chạy trong container:  rake sitetor_listing:backfill
# Chạy lại an toàn (idempotent) — chỉ ghi đè field khi parse ra giá trị.
desc "Parse giá/mặt tiền/diện tích cho toàn bộ topic BĐS cũ"
task "sitetor_listing:backfill" => :environment do
  cat_ids = SitetorListing::Extract.category_ids # đã gồm sub-category
  scope = Topic.where(category_id: cat_ids).where(deleted_at: nil)
  total = scope.count
  done = 0
  hit = 0

  # Dọn giá trị rác từ các lần backfill trước (không phải số, hoặc giá ngoài khoảng hợp lý)
  cleaned = TopicCustomField
    .where(name: [SitetorListing::FIELD_GIA, SitetorListing::FIELD_MAT_TIEN, SitetorListing::FIELD_DIEN_TICH])
    .where.not("value ~ '^\\d+(\\.\\d+)?$'")
    .delete_all
  cleaned += TopicCustomField
    .where(name: SitetorListing::FIELD_GIA)
    .where(
      "CAST(value AS numeric) < ? OR CAST(value AS numeric) > ?",
      SitetorListing::Parser::GIA_MIN_HOP_LY,
      SitetorListing::Parser::GIA_MAX_HOP_LY,
    )
    .delete_all
  puts "Đã dọn #{cleaned} giá trị rác." if cleaned > 0

  puts "Backfill #{total} topics trong categories #{cat_ids.inspect}..."

  scope.find_each do |topic|
    first_post = topic.first_post
    next unless first_post

    # dùng chung logic với hook realtime (giá/MT/DT + loại/vị trí/hướng + địa chỉ)
    if SitetorListing::Extract.apply(topic, "#{topic.title} #{first_post.raw}")
      topic.save_custom_fields(true)
      hit += 1
    end

    done += 1
    puts "  #{done}/#{total} (trích được: #{hit})" if (done % 500).zero?
  end

  puts "Xong: #{done} topics, trích được dữ liệu: #{hit} (#{(hit * 100.0 / [total, 1].max).round}%)"
end
