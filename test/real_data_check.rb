# frozen_string_literal: true

# Đo tỷ lệ trích xuất trên dữ liệu THẬT (không chạy trong CI — cần file /tmp/real_topics.json
# tạo bởi script fetch từ lms.sitetor.com). Dùng để đánh giá parser trước khi backfill.
require "json"
require_relative "../lib/sitetor_listing/parser"

rows = JSON.parse(File.read(ARGV[0] || "/tmp/real_topics.json", encoding: "utf-8"))
stats = { gia: 0, mat_tien: 0, dien_tich: 0, any: 0 }
misses = []

rows.each do |r|
  res = SitetorListing::Parser.parse("#{r["title"]} #{r["excerpt"]}")
  stats[:gia] += 1 if res[:gia]
  stats[:mat_tien] += 1 if res[:mat_tien]
  stats[:dien_tich] += 1 if res[:dien_tich]
  if res.values.any?
    stats[:any] += 1
  else
    misses << r["title"][0, 70]
  end
end

n = rows.size.to_f
puts "Tổng #{rows.size} tin thật:"
puts "  Giá:       #{stats[:gia]} (#{(stats[:gia] / n * 100).round}%)"
puts "  Mặt tiền:  #{stats[:mat_tien]} (#{(stats[:mat_tien] / n * 100).round}%)"
puts "  Diện tích: #{stats[:dien_tich]} (#{(stats[:dien_tich] / n * 100).round}%)"
puts "  Ít nhất 1 trường: #{stats[:any]} (#{(stats[:any] / n * 100).round}%)"
puts "--- Tin không trích được gì (tối đa 10):"
misses.first(10).each { |m| puts "  · #{m}" }
