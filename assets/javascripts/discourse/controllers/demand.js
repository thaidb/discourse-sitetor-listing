import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import RecommendListingModal from "discourse/plugins/discourse-sitetor-listing/discourse/components/modal/recommend-listing";

const PRICE_UNITS = { million: 1e6, billion: 1e9 };

// Trang Cầu: mỗi topic nhu cầu là 1 buylead (bộ lọc lưu sẵn). Bộ lọc dùng
// range GIAO NHAU (ngân sách/diện tích/mặt tiền) + multi JSON-array (loại BĐS,
// khu vực, hướng, vị trí, mục đích, ngành). Cấu trúc điều khiển mirror /listing.
export default class DemandController extends Controller {
  @service siteSettings;
  @service site;
  @service currentUser;
  @service modal;

  queryParams = [
    "q",
    "budget_min",
    "budget_max",
    "area_min",
    "area_max",
    "frontage_min",
    "frontage_max",
    "floor_min",
    "floor_max",
    "category_id",
    "sort",
    "page",
    "demand_type",
    "property_types",
    "provinces",
    "districts",
    "directions",
    "positions",
    "purpose",
    "industry",
  ];

  @tracked q = null;
  @tracked budget_min = null;
  @tracked budget_max = null;
  @tracked area_min = null;
  @tracked area_max = null;
  @tracked frontage_min = null;
  @tracked frontage_max = null;
  @tracked floor_min = null;
  @tracked floor_max = null;
  @tracked category_id = null;
  @tracked sort = null;
  @tracked page = 0;
  @tracked demand_type = null;
  @tracked property_types = null;
  @tracked provinces = null;
  @tracked districts = null;
  @tracked directions = null;
  @tracked positions = null;
  @tracked purpose = null;
  @tracked industry = null;

  // input tạm — chỉ áp vào queryParams khi bấm Lọc
  @tracked fQ = "";
  @tracked fBudgetMin = "";
  @tracked fBudgetMax = "";
  @tracked fBudgetUnit = "billion"; // triệu | tỷ | usd
  @tracked fAreaMin = "";
  @tracked fAreaMax = "";
  @tracked fFrontageMin = "";
  @tracked fFrontageMax = "";
  @tracked fFloorMin = "";
  @tracked fFloorMax = "";
  @tracked fSort = "new";
  @tracked sDemandType = [];
  @tracked sPropertyTypes = [];
  @tracked sProvinces = [];
  @tracked sDistricts = [];
  @tracked sDirections = [];
  @tracked sPositions = [];
  @tracked sPurpose = [];
  @tracked sIndustry = [];

  @tracked facets = {};
  @tracked fGotoPage = "";
  // đặt khi ở trang landing /demand/:slug → hiện H1 riêng của ngành nghề
  @tracked landingName = null;
  // ngành nghề đang active (để tô đậm chip trong panel) — KHÔNG phải queryParam,
  // tránh nhét ?industry=... trùng vào URL landing /demand/:slug
  @tracked activeIndustry = null;

  get topics() {
    return this.model?.topics || [];
  }

  get total() {
    return this.model?.total || 0;
  }

  get perPage() {
    return this.model?.per_page || this.siteSettings.sitetor_listing_page_size || 30;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.total / this.perPage));
  }

  get currentPage() {
    return Number(this.page) + 1;
  }

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
    try {
      this.facets = await ajax("/listing/demand-facets.json");
    } catch {
      this.facets = {};
    }
  }

  budgetToVnd(v) {
    if (v === "" || v === null) {
      return null;
    }
    const rate =
      this.fBudgetUnit === "usd"
        ? this.siteSettings.sitetor_listing_usd_rate || 26000
        : PRICE_UNITS[this.fBudgetUnit] || 1e6;
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
  }

  collectFilterParams() {
    const num = (v) => (v === "" || v === null ? null : Number(v));
    const csv = (arr) => (arr.length ? arr.join(",") : null);
    return {
      q: this.fQ || null,
      budget_min: this.budgetToVnd(this.fBudgetMin),
      budget_max: this.budgetToVnd(this.fBudgetMax),
      area_min: num(this.fAreaMin),
      area_max: num(this.fAreaMax),
      frontage_min: num(this.fFrontageMin),
      frontage_max: num(this.fFrontageMax),
      floor_min: num(this.fFloorMin),
      floor_max: num(this.fFloorMax),
      sort: this.fSort === "new" ? null : this.fSort,
      demand_type: csv(this.sDemandType),
      property_types: csv(this.sPropertyTypes),
      provinces: csv(this.sProvinces),
      districts: csv(this.sDistricts),
      directions: csv(this.sDirections),
      positions: csv(this.sPositions),
      purpose: csv(this.sPurpose),
      industry: csv(this.sIndustry),
      page: 0,
    };
  }

  @action
  applyFilter() {
    const p = this.collectFilterParams();
    for (const [k, v] of Object.entries(p)) {
      this[k] = v;
    }
  }

  @action
  resetFilter() {
    this.fQ = "";
    this.fBudgetMin = this.fBudgetMax = this.fAreaMin = this.fAreaMax = this.fFrontageMin = this.fFrontageMax = this.fFloorMin = this.fFloorMax = "";
    this.fBudgetUnit = "billion";
    this.fSort = "new";
    this.sDemandType = [];
    this.sPropertyTypes = [];
    this.sProvinces = [];
    this.sDistricts = [];
    this.sDirections = [];
    this.sPositions = [];
    this.sPurpose = [];
    this.sIndustry = [];
    this.applyFilter();
  }

  @action
  updateGotoPage(event) {
    this.fGotoPage = event.target.value;
  }

  @action
  gotoPage() {
    const n = parseInt(this.fGotoPage, 10);
    if (!isNaN(n)) {
      this.goPage(Math.min(Math.max(n, 1), this.totalPages));
      this.fGotoPage = "";
    }
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

  // "Giới thiệu BĐS của bạn" cho 1 nhu cầu: mở modal chọn listing của mình →
  // reply gắn link vào topic nhu cầu (tái dùng flow recommend của topic footer).
  @action
  openRecommend(topic) {
    this.modal.show(RecommendListingModal, {
      model: { topic: { id: topic.id, slug: topic.slug } },
    });
  }
}
