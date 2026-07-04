import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class ListingController extends Controller {
  @service siteSettings;

  queryParams = [
    "gia_min",
    "gia_max",
    "mt_min",
    "mt_max",
    "dt_min",
    "dt_max",
    "category_id",
    "page",
  ];

  @tracked gia_min = null;
  @tracked gia_max = null;
  @tracked mt_min = null;
  @tracked mt_max = null;
  @tracked dt_min = null;
  @tracked dt_max = null;
  @tracked category_id = null;
  @tracked page = 0;

  // input tạm (đơn vị thân thiện: giá nhập bằng TRIỆU đồng)
  @tracked fGiaMin = "";
  @tracked fGiaMax = "";
  @tracked fMtMin = "";
  @tracked fMtMax = "";
  @tracked fDtMin = "";
  @tracked fDtMax = "";

  get topics() {
    return this.model?.topics || [];
  }

  get total() {
    return this.model?.total || 0;
  }

  get hasPrev() {
    return this.page > 0;
  }

  get hasNext() {
    const per = this.siteSettings.sitetor_filter_page_size || 30;
    return (this.page + 1) * per < this.total;
  }

  @action
  applyFilter() {
    const trieu = (v) => (v === "" || v === null ? null : Number(v) * 1e6);
    const num = (v) => (v === "" || v === null ? null : Number(v));
    this.gia_min = trieu(this.fGiaMin);
    this.gia_max = trieu(this.fGiaMax);
    this.mt_min = num(this.fMtMin);
    this.mt_max = num(this.fMtMax);
    this.dt_min = num(this.fDtMin);
    this.dt_max = num(this.fDtMax);
    this.page = 0;
  }

  @action
  resetFilter() {
    this.fGiaMin = this.fGiaMax = this.fMtMin = this.fMtMax = this.fDtMin = this.fDtMax = "";
    this.applyFilter();
  }

  @action
  prevPage() {
    if (this.hasPrev) {
      this.page -= 1;
    }
  }

  @action
  nextPage() {
    if (this.hasNext) {
      this.page += 1;
    }
  }
}
