# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/sitetor_filter/address_matcher"
require_relative "../lib/sitetor_filter/attributes"

class AddressMatcherTest < Minitest::Test
  # dùng catalog THẬT đóng gói trong plugin
  M = SitetorFilter::AddressMatcher.default

  def test_quan_so
    r = M.match("Cho thuê nhà mặt tiền Quận 3 giá tốt")
    assert_equal "Quận 3", r[:quan]
    assert_equal "TP Hồ Chí Minh", r[:tinh]
  end

  def test_quan_viet_tat
    assert_equal "Quận 1", M.match("nhà đẹp Q1 tiện kinh doanh")[:quan]
    assert_equal "Quận 10", M.match("bán nhà q.10 hxh")[:quan]
  end

  def test_quan_ten_chu
    assert_equal "Quận Gò Vấp", M.match("cho thuê nhà Gò Vấp 2 lầu")[:quan]
    assert_equal "Quận Bình Thạnh", M.match("nhà Bình Thạnh gần chợ")[:quan]
  end

  def test_khong_nham_quan_1_voi_12
    assert_equal "Quận 12", M.match("bán đất quận 12 sổ riêng")[:quan]
  end

  def test_duong_va_so_nha
    r = M.match("Cho thuê nhà 340 Ung Văn Khiêm, Bình Thạnh")
    assert_equal "Quận Bình Thạnh", r[:quan]
    assert_equal "Ung Văn Khiêm", r[:duong]
    assert_equal "340", r[:so_nha]
  end

  def test_duong_pasteur_quan_3
    r = M.match("Cho thuê nhà mặt tiền đường Pasteur Quận 3")
    assert_equal "Pasteur", r[:duong]
    assert_equal "Quận 3", r[:quan]
  end

  def test_so_nha_co_xuyet
    r = M.match("Bán nhà 12/34 Nguyễn Văn Đậu Bình Thạnh")
    assert_equal "Nguyễn Văn Đậu", r[:duong]
    assert_equal "12/34", r[:so_nha]
  end

  def test_phuong_so
    r = M.match("nhà Phường 12 Quận 10")
    assert_equal "Quận 10", r[:quan]
    assert_equal "Phường 12", r[:phuong]
  end

  def test_phuong_ten_chu
    r = M.match("căn hộ Thảo Điền Quận 2")
    assert_equal "Quận 2", r[:quan]
    assert_equal "Thảo Điền", r[:phuong]
  end

  def test_khong_co_dia_chi
    r = M.match("Cần tư vấn hợp đồng thuê nhà")
    assert_nil r[:quan]
    assert_nil r[:duong]
  end

  def test_khong_nham_ten_duong_thanh_quan_tinh_khac
    # "Nguyễn Huệ" từng bị nhầm thành TP Huế; "Tân Sơn" nhầm huyện tỉnh khác
    r = M.match("Lịch sử chào Đường Nguyễn Huệ TPHCM từ năm 2015")
    assert_equal "Nguyễn Huệ", r[:duong]
    refute_equal "Thành phố Huế", r[:quan]
    r2 = M.match("Lịch sử chào Tân Sơn từ năm 2015 cho đến nay")
    assert_nil r2[:quan]
    assert_equal "Tân Sơn", r2[:duong]
  end
end

class AttributesTest < Minitest::Test
  A = SitetorFilter::Attributes

  def test_loai
    assert_equal "Văn phòng", A.extract("cho thuê văn phòng 100m2")[:loai]
    assert_equal "Kho, nhà xưởng", A.extract("kho xưởng 500m2 Bình Tân")[:loai]
    assert_equal "Căn hộ, chung cư", A.extract("căn hộ 2PN full nội thất")[:loai]
    assert_equal "Nhà mặt phố", A.extract("nhà mặt tiền Lê Lợi")[:loai]
    assert_equal "Nhà hẻm", A.extract("nhà HXH 6m thông")[:loai]
    assert_equal "Bán đất", A.extract("bán đất nền dự án")[:loai]
    assert_nil A.extract("cần tư vấn")[:loai]
  end

  def test_vi_tri
    assert_equal "Mặt tiền", A.extract("nhà mặt tiền đường lớn")[:vi_tri]
    assert_equal "Hẻm", A.extract("nhà trong hẻm xe hơi")[:vi_tri]
    assert_equal "Khu Compound", A.extract("villa khu compound an ninh")[:vi_tri]
  end

  def test_huong
    assert_equal "Đông Nam", A.extract("nhà hướng Đông Nam mát mẻ")[:huong]
    assert_equal "Tây", A.extract("cửa hướng tây")[:huong]
    assert_nil A.extract("khu nam sài gòn")[:huong]
  end
end
