export default function () {
  this.route("listing");
  // SEO filter pages: /listing/ban/nha-mat-pho/quan-3/duong-vo-van-tan
  this.route("listing-seo", { path: "/listing/*filters" });
}
