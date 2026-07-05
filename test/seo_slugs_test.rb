# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/sitetor_filter/seo_slugs"

class SeoSlugsTest < Minitest::Test
  S = SitetorFilter::SeoSlugs.default
  CATS = { "ban" => 3722, "cho-thue-nha-dat" => 3412 }.freeze

  def test_parse_day_du
    r = S.parse(%w[ban nha-mat-pho quan-3 duong-vo-van-tan], category_slugs: CATS)
    assert_equal 3722, r[:category_id]
    assert_equal "Nhà mặt phố", r[:loai]
    assert_equal "Quận 3", r[:quan]
    assert_equal "Võ Văn Tần", r[:duong]
  end

  def test_parse_quan_chu
    r = S.parse(%w[quan-go-vap], category_slugs: CATS)
    assert_equal "Quận Gò Vấp", r[:quan]
  end

  def test_parse_phuong_va_huong_va_trang
    r = S.parse(%w[phuong-thao-dien huong-dong-nam trang-3], category_slugs: CATS)
    assert_equal "Thảo Điền", r[:phuong]
    assert_equal "Đông Nam", r[:huong]
    assert_equal 2, r[:page]
  end

  def test_parse_segment_la_tra_ve_nil
    assert_nil S.parse(%w[ban xyz-khong-ton-tai], category_slugs: CATS)
  end

  def test_build_roundtrip
    path = S.build(category_slug: "ban", loai: "Nhà mặt phố", quan: "Quận 3", duong: "Võ Văn Tần")
    assert_equal "ban/nha-mat-pho/quan-3/duong-vo-van-tan", path
    r = S.parse(path.split("/"), category_slugs: CATS)
    assert_equal "Nhà mặt phố", r[:loai]
    assert_equal "Võ Văn Tần", r[:duong]
  end

  def test_title
    t = S.title(category_name: "Bán", loai: "Nhà mặt phố", quan: "Quận 3", duong: "Võ Văn Tần")
    assert_equal "Bán Nhà mặt phố đường Võ Văn Tần Quận 3", t
  end

  def test_title_phan_trang
    t = S.title(category_name: "Cho thuê", quan: "Quận 1", page: 2)
    assert_equal "Cho thuê Quận 1 - Trang 3", t
  end
end
