# frozen_string_literal: true

# Trích xuất giá / mặt tiền / diện tích từ text tin BĐS tiếng Việt.
# Pure Ruby — không phụ thuộc Discourse, test được độc lập (test/parser_test.rb).
module SitetorFilter
  module Parser
    # Tỷ giá USD→VND dùng khi tin ghi giá bằng USD (site setting override được)
    DEFAULT_USD_RATE = 26_000

    NUM = /\d+(?:[.,]\d+)?/

    module_function

    # @return [Hash] { gia: Integer|nil (VND), mat_tien: Float|nil (m), dien_tich: Float|nil (m2) }
    def parse(text, usd_rate: DEFAULT_USD_RATE)
      t = normalize(text)
      dims = extract_dimensions(t)
      {
        gia: extract_price(t, usd_rate: usd_rate),
        mat_tien: extract_frontage(t) || dims[:ngang],
        dien_tich: extract_area(t) || dims[:dien_tich],
      }
    end

    def normalize(text)
      t = text.to_s.downcase
      t = t.tr(" ", " ")
      # bỏ dấu tiếng Việt cho phần keyword matching (giữ bản gốc số nguyên vẹn)
      t.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
    end

    # --- Giá ---------------------------------------------------------------
    # "5 tỷ", "5,5 ty", "5 tỷ 500", "gia ban 12 ti", "25 triệu/tháng", "25tr/thang",
    # "gia thue 3.500 usd", "3000$/thang"
    # Giá hợp lý: 100 nghìn (thuê rẻ nhất) .. 20.000 tỷ — ngoài khoảng coi là rác
    GIA_MIN_HOP_LY = 100_000
    GIA_MAX_HOP_LY = 20_000_000_000_000

    def extract_price(t, usd_rate: DEFAULT_USD_RATE)
      # X tỷ Y (triệu)  vd "5 tỷ 500"
      if (m = t.match(/(#{NUM})\s*(?:ty|ti)\b(?:\s*(\d{1,3})\b(?!\s*(?:m2|m\b|%)))?/))
        ty = to_f(m[1])
        trieu = m[2] ? m[2].to_f : 0
        return clamp_price((ty * 1_000_000_000 + trieu * 1_000_000).round)
      end
      # X triệu / X tr  (thuê theo tháng hoặc giá triệu)
      if (m = t.match(/(#{NUM})\s*(?:trieu|tr)\b/))
        return clamp_price((to_f(m[1]) * 1_000_000).round)
      end
      # USD: "3.500 usd", "3500$", "$3500"
      if (m = t.match(/(?:\$\s*)(\d{3,6})\b/) || t.match(/(\d{1,3}(?:[.,]\d{3})*|\d{3,6})\s*(?:usd|\$)/))
        usd = m[1].gsub(/[.,]/, "").to_i
        return clamp_price(usd * usd_rate) if usd >= 100 # tránh nhầm số nhỏ
      end
      nil
    end

    def clamp_price(vnd)
      vnd.between?(GIA_MIN_HOP_LY, GIA_MAX_HOP_LY) ? vnd : nil
    end

    # --- Mặt tiền ----------------------------------------------------------
    # "mặt tiền 6m", "mt 6m", "ngang 5m", "ngang 4,5m", "rộng 6m"
    def extract_frontage(t)
      if (m = t.match(/(?:mat\s*tien|\bmt\b|ngang|rong)[^\d]{0,12}(#{NUM})\s*m(?![²2\w])?/))
        v = to_f(m[1])
        return v if v > 0.5 && v < 100
      end
      nil
    end

    # --- Diện tích ---------------------------------------------------------
    # "100m2", "100 m²", "dt 100m2", "diện tích: 100,5 m2", "1000m vuong"
    def extract_area(t)
      if (m = t.match(/(?:dien\s*tich|\bdt\b|\bdtsd\b)[^\d]{0,12}(#{NUM})\s*m/)) ||
         (m = t.match(/(#{NUM})\s*(?:m2|m²|m\s*vuong)/))
        v = to_f(m[1])
        return v if v >= 5 && v < 1_000_000
      end
      nil
    end

    # --- Kích thước "5x20" -------------------------------------------------
    # "5x20", "5 x 20m", "4,5x18", "(5m x 20m)" → ngang 5, dien_tich 100
    def extract_dimensions(t)
      if (m = t.match(/(#{NUM})\s*m?\s*[x×*]\s*(#{NUM})\s*m?\b/))
        a = to_f(m[1])
        b = to_f(m[2])
        # loại nhầm lẫn kiểu ngày tháng/số nhà: cạnh hợp lý 1..200m
        if a > 0.9 && a <= 200 && b > 0.9 && b <= 200
          ngang = [a, b].min
          return { ngang: ngang, dien_tich: (a * b).round(1) }
        end
      end
      { ngang: nil, dien_tich: nil }
    end

    def to_f(s)
      s.to_s.tr(",", ".").to_f
    end
  end
end
