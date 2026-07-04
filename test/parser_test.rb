# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/sitetor_filter/parser"

class ParserTest < Minitest::Test
  P = SitetorFilter::Parser

  # --- Giá ---
  def test_gia_ty
    assert_equal 5_000_000_000, P.parse("Bán nhà giá 5 tỷ")[:gia]
  end

  def test_gia_ty_le
    assert_equal 5_500_000_000, P.parse("giá 5,5 tỷ")[:gia]
    assert_equal 12_000_000_000, P.parse("gia ban 12 ti thuong luong")[:gia]
  end

  def test_gia_ty_kem_trieu
    assert_equal 5_500_000_000, P.parse("bán gấp 5 tỷ 500")[:gia]
  end

  def test_gia_trieu_thang
    assert_equal 25_000_000, P.parse("cho thuê 25 triệu/tháng")[:gia]
    assert_equal 25_000_000, P.parse("giá thuê 25tr/tháng")[:gia]
  end

  def test_gia_usd
    assert_equal 3_500 * 26_000, P.parse("giá thuê 3.500 USD")[:gia]
    assert_equal 3_000 * 26_000, P.parse("thuê $3000 mỗi tháng")[:gia]
  end

  def test_khong_nham_sdt_thanh_gia
    assert_nil P.parse("Liên hệ 0901234567 chính chủ")[:gia]
  end

  def test_gia_phi_ly_bi_loai
    # số điện thoại dính chữ "tỷ" hoặc giá troll → nil, không được lọt vào DB
    assert_nil P.parse("giá 0901234567 tỷ")[:gia]
    assert_nil P.parse("bán 999999999 tỷ")[:gia]
    assert_equal 20_000_000_000_000, P.parse("tòa nhà 20000 tỷ")[:gia]
  end

  # --- Mặt tiền ---
  def test_mat_tien
    assert_in_delta 6.0, P.parse("nhà mặt tiền 6m đường lớn")[:mat_tien]
    assert_in_delta 4.5, P.parse("MT 4,5m nở hậu")[:mat_tien]
    assert_in_delta 5.0, P.parse("ngang 5m dài 20m")[:mat_tien]
  end

  # --- Diện tích ---
  def test_dien_tich
    assert_in_delta 100.0, P.parse("DT 100m2")[:dien_tich]
    assert_in_delta 85.5, P.parse("diện tích: 85,5 m²")[:dien_tich]
    assert_in_delta 1000.0, P.parse("khuôn viên 1000m vuông")[:dien_tich]
  end

  # --- Kích thước ngang x dài ---
  def test_kich_thuoc_x
    r = P.parse("nhà 5x20 hẻm xe hơi")
    assert_in_delta 5.0, r[:mat_tien]
    assert_in_delta 100.0, r[:dien_tich]
  end

  def test_kich_thuoc_x_don_vi
    r = P.parse("khuôn đất (4,5m x 18m) vuông vức")
    assert_in_delta 4.5, r[:mat_tien]
    assert_in_delta 81.0, r[:dien_tich]
  end

  def test_uu_tien_dt_ghi_ro_hon_tich_x
    r = P.parse("5x20 nhưng DT công nhận 95m2")
    assert_in_delta 95.0, r[:dien_tich]
    assert_in_delta 5.0, r[:mat_tien]
  end

  def test_khong_nham_ngay_thang
    assert_nil P.parse("đăng ngày 30/4 xem nhà 24/7")[:dien_tich]
  end

  # --- Tổng hợp tin thật ---
  def test_tin_tong_hop
    r = P.parse("Cho thuê nhà MT Lê Lợi Q1, ngang 6m, DT 120m2, giá 80 triệu/tháng")
    assert_equal 80_000_000, r[:gia]
    assert_in_delta 6.0, r[:mat_tien]
    assert_in_delta 120.0, r[:dien_tich]
  end

  def test_tin_ban
    r = P.parse("Bán nhà 2 mặt tiền 8m x 25m, giá 45 tỷ TL")
    assert_equal 45_000_000_000, r[:gia]
    assert_in_delta 8.0, r[:mat_tien]
    assert_in_delta 200.0, r[:dien_tich]
  end

  def test_khong_co_gi
    r = P.parse("Cần tư vấn pháp lý sổ hồng")
    assert_nil r[:gia]
    assert_nil r[:mat_tien]
    assert_nil r[:dien_tich]
  end
end
