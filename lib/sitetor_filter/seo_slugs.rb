# frozen_string_literal: true

require "json"

# SEO filter pages: chuyển đổi 2 chiều giữa URL đẹp và bộ lọc.
#   /listing/ban/nha-mat-pho/quan-3/duong-vo-van-tan
#   ↔ { category_slug: "ban", loai: "Nhà mặt phố", quan: "Quận 3", duong: "Võ Văn Tần" }
# Mỗi loại segment có quy ước riêng để parse không nhầm lẫn:
#   loại SP: slug trần ("nha-mat-pho") | quận: "quan-3"/"quan-go-vap"
#   phường: "phuong-12"/"phuong-thao-dien" | đường: "duong-vo-van-tan"
#   vị trí: "vi-tri-mat-tien" | hướng: "huong-dong-nam"
# Pure Ruby (catalog.json), test độc lập.
module SitetorFilter
  class SeoSlugs
    CATALOG_PATH = File.expand_path("data/catalog.json", __dir__)

    LOAI = [
      "Nhà mặt phố", "Nhà hẻm", "Văn phòng", "Kho, nhà xưởng",
      "Căn hộ, chung cư", "Bán đất", "Tầng thương mại",
    ].freeze
    VI_TRI = ["Mặt tiền", "Đường Nội Bộ", "Hẻm", "Khu Compound"].freeze
    HUONG = ["Đông", "Tây", "Nam", "Bắc", "Đông Nam", "Đông Bắc", "Tây Nam", "Tây Bắc"].freeze

    def self.default
      @default ||= new(JSON.parse(File.read(CATALOG_PATH, encoding: "utf-8")))
    end

    def self.slugify(s)
      s.to_s.downcase.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("đ", "d")
        .gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def initialize(catalog)
      s = self.class.method(:slugify)
      @loai = LOAI.to_h { |v| [s.call(v), v] }
      @vi_tri = VI_TRI.to_h { |v| ["vi-tri-#{s.call(v)}", v] }
      @huong = HUONG.to_h { |v| ["huong-#{s.call(v)}", v] }
      @quan = catalog["districts"].to_h { |d| ["quan-#{s.call(strip_quan(d["name"]))}", d["name"]] }
      @phuong = catalog["wards"].to_h { |w| ["phuong-#{s.call(strip_phuong(w["name"]))}", w["name"]] }
      @duong = catalog["streets"].to_h { |st| ["duong-#{s.call(st["name"])}", st["name"]] }
    end

    # @param segments [Array<String>] các đoạn path (không gồm category slug)
    # @param category_slugs [Hash] slug → category_id (từ setting, tra ở controller)
    # @return [Hash, nil] filter params; nil nếu có segment không nhận diện được (→ 404)
    def parse(segments, category_slugs: {})
      out = {}
      segments.each do |seg|
        seg = seg.to_s.downcase
        if category_slugs.key?(seg)
          out[:category_id] = category_slugs[seg]
          out[:category_slug] = seg
        elsif @loai.key?(seg) then out[:loai] = @loai[seg]
        elsif @vi_tri.key?(seg) then out[:vi_tri] = @vi_tri[seg]
        elsif @huong.key?(seg) then out[:huong] = @huong[seg]
        elsif @quan.key?(seg) then out[:quan] = @quan[seg]
        elsif @phuong.key?(seg) then out[:phuong] = @phuong[seg]
        elsif @duong.key?(seg) then out[:duong] = @duong[seg]
        elsif (m = seg.match(/\Atrang-(\d+)\z/)) then out[:page] = m[1].to_i - 1
        else
          return nil
        end
      end
      out
    end

    # Ngược lại: từ filter (mỗi chiều 1 giá trị) → path segments theo thứ tự đẹp
    def build(category_slug: nil, loai: nil, vi_tri: nil, huong: nil, quan: nil, phuong: nil, duong: nil, page: nil)
      s = self.class.method(:slugify)
      segs = []
      segs << category_slug if category_slug
      segs << s.call(loai) if loai
      segs << "vi-tri-#{s.call(vi_tri)}" if vi_tri
      segs << "quan-#{s.call(strip_quan(quan))}" if quan
      segs << "phuong-#{s.call(strip_phuong(phuong))}" if phuong
      segs << "duong-#{s.call(duong)}" if duong
      segs << "huong-#{s.call(huong)}" if huong
      segs << "trang-#{page + 1}" if page && page > 0
      segs.join("/")
    end

    # Title/H1 khớp từ khóa tìm kiếm: "Bán Nhà mặt phố Quận 3 Đường Võ Văn Tần"
    def title(category_name: nil, loai: nil, vi_tri: nil, huong: nil, quan: nil, phuong: nil, duong: nil, page: nil)
      parts = []
      parts << category_name if category_name
      parts << loai if loai
      parts << "vị trí #{vi_tri}" if vi_tri
      parts << "đường #{duong}" if duong
      parts << phuong_display(phuong) if phuong
      parts << quan if quan
      parts << "hướng #{huong}" if huong
      t = parts.join(" ")
      t += " - Trang #{page + 1}" if page && page > 0
      t
    end

    private

    def strip_quan(name)
      name.to_s.sub(/\A(Quận|Huyện|Thành phố|Thị xã)\s+/i, "")
    end

    def strip_phuong(name)
      name.to_s.sub(/\A(Phường|Xã|Thị trấn)\s+/i, "")
    end

    def phuong_display(name)
      name =~ /\A(Phường|Xã|Thị trấn)/i ? name : "phường #{name}"
    end
  end
end
