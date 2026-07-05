# frozen_string_literal: true

# Phân loại thuộc tính tin BĐS từ keyword (không cần catalog):
# loại sản phẩm, vị trí, hướng. Pure Ruby, test độc lập.
module SitetorFilter
  module Attributes
    LOAI = [
      ["Văn phòng", /van\s*phong|office/],
      ["Kho, nhà xưởng", /\bkho\b|nha\s*xuong|\bxuong\b/],
      ["Căn hộ, chung cư", /can\s*ho|chung\s*cu|apartment|studio/],
      ["Tầng thương mại", /tang\s*thuong\s*mai|san\s*thuong\s*mai|shophouse/],
      ["Bán đất", /ban\s*dat|dat\s*nen|ban\s*gap\s*dat|khuon\s*dat|lo\s*dat/],
      ["Nhà mặt phố", /mat\s*tien|mat\s*pho|mat\s*duong|\bmt\b/],
      ["Nhà hẻm", /\bhem\b|\bhxh\b|\bngo\b|trong\s*hem/],
    ].freeze

    VI_TRI = [
      ["Khu Compound", /compound/],
      ["Đường Nội Bộ", /noi\s*bo/],
      ["Mặt tiền", /mat\s*tien|mat\s*pho|mat\s*duong|\bmt\b/],
      ["Hẻm", /\bhem\b|\bhxh\b|\bngo\b/],
    ].freeze

    # đa từ trước, đơn từ sau; yêu cầu có chữ "hướng" đứng trước để tránh nhầm
    HUONG = [
      ["Đông Nam", /huong\s*dong\s*nam/],
      ["Đông Bắc", /huong\s*dong\s*bac/],
      ["Tây Nam", /huong\s*tay\s*nam/],
      ["Tây Bắc", /huong\s*tay\s*bac/],
      ["Đông", /huong\s*dong/],
      ["Tây", /huong\s*tay/],
      ["Nam", /huong\s*nam/],
      ["Bắc", /huong\s*bac/],
    ].freeze

    module_function

    def normalize(s)
      s.to_s.downcase.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("đ", "d")
    end

    def extract(text)
      t = normalize(text)
      {
        loai: LOAI.find { |_, re| t =~ re }&.first,
        vi_tri: VI_TRI.find { |_, re| t =~ re }&.first,
        huong: HUONG.find { |_, re| t =~ re }&.first,
      }
    end
  end
end
