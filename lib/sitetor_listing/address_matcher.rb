# frozen_string_literal: true

require "json"

# Đối chiếu text tin đăng với danh mục địa chỉ (catalog.json export từ CRM):
# tỉnh/thành → quận/huyện → đường + số nhà → phường/xã.
# Pure Ruby, test được độc lập: AddressMatcher.new(catalog_hash).match(text)
module SitetorListing
  class AddressMatcher
    DATA_PATH = File.expand_path("data/catalog.json", __dir__)

    # tên gọi khác của TPHCM (province_id 50 trong catalog)
    HCM_ALIASES = ["tphcm", "tp hcm", "hcm", "ho chi minh", "sai gon", "saigon", "sg"].freeze

    def self.default
      @default ||= new(JSON.parse(File.read(DATA_PATH, encoding: "utf-8")))
    end

    def initialize(catalog)
      @provinces = catalog["provinces"]
      @districts = catalog["districts"]
      @wards = catalog["wards"]
      @streets = catalog["streets"]
      build_indexes
    end

    # @return [Hash] { tinh:, quan:, phuong:, duong:, so_nha: } — giá trị gốc có dấu, nil nếu không thấy
    def match(text)
      t = " #{normalize(text)} "

      district = find_district(t)
      province = find_province(t) || (district && @province_by_id[district["province_id"]])
      street, so_nha = find_street(t, district)
      ward = find_ward(t, district)

      {
        tinh: province && province["name"],
        quan: district && district["name"],
        phuong: ward && display_ward(ward),
        duong: street && street["name"],
        so_nha: so_nha,
      }
    end

    private

    def normalize(s)
      s.to_s.downcase.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("đ", "d")
        .gsub(/[^a-z0-9\/]+/, " ") # dấu câu → space để match ranh giới từ
    end

    def build_indexes
      @province_by_id = @provinces.to_h { |p| [p["id"], p] }
      @province_norm = @provinces.map { |p| [" #{normalize(p["name"])} ", p] }

      # quận đánh số cần regex ranh giới số (tránh "quận 1" khớp "quận 12")
      @districts_numbered, districts_named = @districts.partition { |d| d["name"] =~ /\d/ }
      # TPHCM: match tên trần ("go vap"); tỉnh khác: bắt buộc kèm tiền tố
      # ("huyen tan son") để không nhầm với tên đường/phường trùng chữ
      @district_named_norm =
        districts_named
          .map do |d|
            key =
              if d["province_id"] == 50
                " #{normalize(strip_pre(d["name"], d["pre"]))} "
              else
                # DB nơi có nơi không kèm tiền tố trong name — chuẩn hoá luôn kèm
                " #{normalize("#{d["pre"]} #{strip_pre(d["name"], d["pre"])}")} "
              end
            [key, d]
          end
          .sort_by { |k, _| -k.length }

      @streets_by_district = @streets.group_by { |s| s["district_id"] }
      @street_norm_cache = {}
      @wards_by_district = @wards.group_by { |w| w["district_id"] }
    end

    def strip_pre(name, pre)
      name.sub(/\A#{Regexp.escape(pre)}\s+/i, "")
    end

    def display_ward(ward)
      ward["name"]
    end

    def find_province(t)
      return @province_by_id[50] if HCM_ALIASES.any? { |a| t.include?(" #{a} ") }
      @province_norm.find { |k, _| t.include?(k) }&.last
    end

    def find_district(t)
      # "quận 3", "q3", "q.3" — ranh giới số để không dính "quận 12"
      if (m = t.match(/(?:quan|q)\s*\.?\s*(\d{1,2})(?!\d)/))
        num = m[1].to_i
        d = @districts_numbered.find { |x| x["name"] == "Quận #{num}" }
        return d if d
      end
      # tên chữ: "go vap", "binh thanh", "thu duc"...
      @district_named_norm.find { |k, _| t.include?(k) }&.last
    end

    def find_street(t, district)
      # ưu tiên đường trong quận đã match; không thấy thì mở rộng toàn TPHCM
      # (nhiều đường chạy qua nhiều quận nhưng DB chỉ gán 1 quận)
      if district
        street, so_nha = scan_streets(t, street_norms(district["id"]))
        return [street, so_nha] if street
      end
      hcm_ids = @districts.select { |d| d["province_id"] == 50 }.map { |d| d["id"] }
      scan_streets(t, hcm_ids.flat_map { |id| street_norms(id) })
    end

    def scan_streets(t, candidates)
      best = nil
      best_pos = nil
      candidates.each do |norm, street|
        pos = t.index(norm)
        next unless pos
        next if best && norm.length <= best[0].length
        best = [norm, street]
        best_pos = pos
      end
      return [nil, nil] unless best

      # số nhà: cụm số (có thể 12/34a) đứng ngay trước tên đường
      before = t[0...best_pos]
      so_nha = before[/(\d+[a-z]?(?:\/\d+[a-z]?)*)\s*(?:duong\s+)?\z/, 1]
      [best[1], so_nha]
    end

    def street_norms(district_id)
      @street_norm_cache[district_id] ||=
        (@streets_by_district[district_id] || [])
          .filter_map do |s|
            n = normalize(s["name"]).strip
            next if n.length < 4 # tên quá ngắn dễ khớp nhầm
            [" #{n} ", s]
          end
    end

    def find_ward(t, district)
      return nil unless district
      wards = @wards_by_district[district["id"]] || []

      # "phường 12", "p12", "p.12" — tên trong DB dạng "Phường 12"
      if (m = t.match(/(?:phuong|p)\s*\.?\s*(\d{1,2})(?!\d)/))
        w = wards.find { |x| x["name"] == "Phường #{m[1].to_i}" }
        return w if w
      end
      wards
        .filter_map do |w|
          next if w["name"] =~ /\APhường \d+\z/
          n = " #{normalize(w["name"]).strip} "
          n.length >= 6 && t.include?(n) ? [n, w] : nil
        end
        .max_by { |n, _| n.length }
        &.last
    end
  end
end
