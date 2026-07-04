# discourse-sitetor-bds

Plugin filter BĐS min/max cho **lms.sitetor.com**: lọc theo **giá / mặt tiền / diện tích**
trên toàn bộ tin đăng, hiển thị **bảng so sánh** tại trang `/bds`.

## Tính năng

- Trích tự động `giá (VND)`, `mặt tiền (m)`, `diện tích (m²)` từ tiêu đề + bài viết
  (parser tiếng Việt: `5 tỷ 500`, `25tr/tháng`, `3.500 USD`, `MT 6m`, `ngang 4,5m`,
  `DT 100m2`, `5x20`...), lưu vào topic custom fields dạng số.
- Tin mới / sửa bài đầu → parse tự động (hook `topic_created`, `post_edited`).
- Tin cũ → backfill 1 lần bằng rake task.
- API `GET /bds/filter.json?gia_min=&gia_max=&mt_min=&mt_max=&dt_min=&dt_max=&category_id=&page=`
- Trang `/bds`: thanh lọc min–max (giá nhập theo **triệu**) + bảng 5 cột, mobile cuộn ngang.

## Cài đặt (server tự host, Docker chuẩn Discourse)

1. Đưa repo này lên GitHub (private cũng được, dùng deploy key) hoặc copy trực tiếp.
2. Sửa `/var/discourse/containers/app.yml`, thêm vào `hooks.after_code`:

   ```yaml
   - exec:
       cd: $home/plugins
       cmd:
         - git clone https://github.com/<ban>/discourse-sitetor-bds.git
   ```

3. Rebuild:

   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

4. Vào **Admin → Settings → Plugins**, kiểm tra `sitetor bds enabled` = true và
   `sitetor bds categories` đúng ID category của bạn
   (mặc định: `3412` Cho thuê, `3722` Bán, `3344` Cần thuê, `3698` Cần mua).

5. **Backfill tin cũ** (chạy 1 lần, ~14k tin chỉ vài phút):

   ```bash
   cd /var/discourse
   ./launcher enter app
   rake sitetor_bds:backfill
   ```

6. Mở `https://lms.sitetor.com/bds` — lọc thử `Giá 50–100 triệu`, `Mặt tiền ≥ 6m`.

## Test parser (không cần Discourse)

```bash
ruby test/parser_test.rb          # 15 unit tests
ruby test/real_data_check.rb F    # đo tỷ lệ trích trên dữ liệu thật (file JSON)
```

## Lưu ý dữ liệu

- Topic dạng "Lịch sử chào [tên đường] từ 2015" chứa nhiều căn trong 1 topic nên
  **không có 1 bộ số duy nhất** — parser bỏ qua là đúng. Muốn lọc được loại này
  phải tách mỗi căn 1 topic (hoặc chờ v2: parse bảng trong bài).
- Giá thuê (`triệu/tháng`) và giá bán (`tỷ`) cùng lưu VND — khi lọc nên chọn kèm
  category để min/max có ý nghĩa.

## Roadmap v2 (đã bàn)

- Nút **Apply**: chủ listing chọn tin trong tài khoản để gắn vào topic nhu cầu.
- Form Template khi đăng tin mới → dữ liệu chuẩn 100% không cần parse.
- Cột giá/m², hướng, SĐT chủ nhà (9 cột như spec gốc trên Meta).
