import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

const GIA_UNITS = { trieu: 1e6, ty: 1e9 };

export default class ListingController extends Controller {
  @service siteSettings;
  @service site;

  queryParams = [
    "q",
    "gia_min",
    "gia_max",
    "mt_min",
    "mt_max",
    "dt_min",
    "dt_max",
    "category_id",
    "sort",
    "page",
    "loai",
    "vi_tri",
    "huong",
    "tinh",
    "quan",
    "phuong",
    "duong",
  ];

  @tracked q = null;
  @tracked gia_min = null;
  @tracked gia_max = null;
  @tracked mt_min = null;
  @tracked mt_max = null;
  @tracked dt_min = null;
  @tracked dt_max = null;
  @tracked category_id = null;
  @tracked sort = null;
  @tracked page = 0;
  @tracked loai = null;
  @tracked vi_tri = null;
  @tracked huong = null;
  @tracked tinh = null;
  @tracked quan = null;
  @tracked phuong = null;
  @tracked duong = null;

  // input tạm — chỉ áp vào queryParams khi bấm Lọc
  @tracked fQ = "";
  @tracked fGiaMin = "";
  @tracked fGiaMax = "";
  @tracked fGiaUnit = "trieu"; // trieu | ty | usd
  @tracked fMtMin = "";
  @tracked fMtMax = "";
  @tracked fDtMin = "";
  @tracked fDtMax = "";
  @tracked fCategoryId = "";
  @tracked fSort = "new";
  @tracked sLoai = [];
  @tracked sViTri = [];
  @tracked sHuong = [];
  @tracked sTinh = [];
  @tracked sQuan = [];
  @tracked sPhuong = [];
  @tracked sDuong = [];

  // facets từ /listing/facets.json (phường/đường cascade theo quận đã chọn)
  @tracked facets = {};

  get topics() {
    return this.model?.topics || [];
  }

  get total() {
    return this.model?.total || 0;
  }

  get perPage() {
    return this.model?.per_page || this.siteSettings.sitetor_filter_page_size || 30;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.total / this.perPage));
  }

  get currentPage() {
    return Number(this.page) + 1; // hiển thị 1-based
  }

  get categoryOptions() {
    const ids = (this.siteSettings.sitetor_filter_categories || "")
      .split("|")
      .map((s) => parseInt(s, 10))
      .filter(Boolean);
    return ids.map((id) => {
      const cat = this.site.categories?.find((c) => c.id === id);
      return { id: String(id), name: cat?.name || `#${id}` };
    });
  }

  // Phân trang nhảy bước: 1,2,3,4,5, 10,15,...,95, 100,200,..., n
  get pageList() {
    const n = this.totalPages;
    const pages = new Set();
    for (let i = 1; i <= Math.min(5, n); i++) {
      pages.add(i);
    }
    for (let i = 10; i < Math.min(100, n); i += 5) {
      pages.add(i);
    }
    for (let i = 100; i <= n; i += 100) {
      pages.add(i);
    }
    pages.add(n);
    pages.add(this.currentPage);
    return [...pages]
      .sort((a, b) => a - b)
      .map((p) => ({ num: p, current: p === this.currentPage }));
  }

  get hasPrev() {
    return this.currentPage > 1;
  }

  get hasNext() {
    return this.currentPage < this.totalPages;
  }

  async loadFacets() {
    const data = {};
    if (this.sQuan.length) {
      data.quan = this.sQuan.join(",");
    }
    try {
      this.facets = await ajax("/listing/facets.json", { data });
    } catch {
      this.facets = {};
    }
  }

  giaToVnd(v) {
    if (v === "" || v === null) {
      return null;
    }
    const rate =
      this.fGiaUnit === "usd"
        ? this.siteSettings.sitetor_filter_usd_rate || 26000
        : GIA_UNITS[this.fGiaUnit] || 1e6;
    return Number(v) * rate;
  }

  @action
  updateField(name, event) {
    this[name] = event.target.value;
  }

  @action
  onQKeydown(event) {
    if (event.key === "Enter") {
      this.applyFilter();
    }
  }

  @action
  setSelection(name, values) {
    this[name] = values;
    if (name === "sQuan") {
      // cascade: đổi quận → nạp lại danh sách phường/đường
      this.sPhuong = [];
      this.sDuong = [];
      this.loadFacets();
    }
  }

  @action
  applyFilter() {
    const num = (v) => (v === "" || v === null ? null : Number(v));
    const csv = (arr) => (arr.length ? arr.join(",") : null);
    this.q = this.fQ || null;
    this.gia_min = this.giaToVnd(this.fGiaMin);
    this.gia_max = this.giaToVnd(this.fGiaMax);
    this.mt_min = num(this.fMtMin);
    this.mt_max = num(this.fMtMax);
    this.dt_min = num(this.fDtMin);
    this.dt_max = num(this.fDtMax);
    this.category_id = this.fCategoryId || null;
    this.sort = this.fSort === "new" ? null : this.fSort;
    this.loai = csv(this.sLoai);
    this.vi_tri = csv(this.sViTri);
    this.huong = csv(this.sHuong);
    this.tinh = csv(this.sTinh);
    this.quan = csv(this.sQuan);
    this.phuong = csv(this.sPhuong);
    this.duong = csv(this.sDuong);
    this.page = 0;
  }

  @action
  resetFilter() {
    this.fQ = "";
    this.fGiaMin = this.fGiaMax = this.fMtMin = this.fMtMax = this.fDtMin = this.fDtMax = "";
    this.fGiaUnit = "trieu";
    this.fCategoryId = "";
    this.fSort = "new";
    this.sLoai = [];
    this.sViTri = [];
    this.sHuong = [];
    this.sTinh = [];
    this.sQuan = [];
    this.sPhuong = [];
    this.sDuong = [];
    this.applyFilter();
    this.loadFacets();
  }

  @action
  goPage(p) {
    this.page = p - 1;
  }

  @action
  prevPage() {
    if (this.hasPrev) {
      this.page = Number(this.page) - 1;
    }
  }

  @action
  nextPage() {
    if (this.hasNext) {
      this.page = Number(this.page) + 1;
    }
  }
}
