export default function () {
  this.route("listing");
  // SEO filter pages: /listing/ban/nha-mat-pho/district-3/street-vo-van-tan
  this.route("listing-seo", { path: "/listing/*filters" });
  // Trang Cầu (nhu cầu Cần mua/Cần thuê) — card kiểu buylead, style native
  this.route("demand");
  // Landing 1 ngành nghề: /demand/thoi-trang (dùng lại controller/template demand)
  this.route("demand-tag", { path: "/demand/:slug" });
}
