import { action } from "@ember/object";
import { service } from "@ember/service";
import ListingController from "./listing";

// Controller trang SEO — dùng chung UI với /listing; thao tác lọc/phân trang
// chuyển hướng về URL tương ứng (giữ URL đẹp cho phân trang, query cho lọc tự do).
export default class ListingSeoController extends ListingController {
  @service router;

  @action
  applyFilter() {
    this.router.transitionTo("listing", {
      queryParams: this.collectFilterParams(),
    });
  }

  @action
  goPage(p) {
    const base = this.model?.seo_base;
    if (base) {
      this.router.transitionTo(`/listing/${base}${p > 1 ? `/trang-${p}` : ""}`);
    } else {
      this.router.transitionTo("listing", {
        queryParams: { ...this.collectFilterParams(), page: p - 1 },
      });
    }
  }

  @action
  prevPage() {
    if (this.hasPrev) {
      this.goPage(this.currentPage - 1);
    }
  }

  @action
  nextPage() {
    if (this.hasNext) {
      this.goPage(this.currentPage + 1);
    }
  }
}
