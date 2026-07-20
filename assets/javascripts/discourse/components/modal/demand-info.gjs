import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input, Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import MultiSelect from "discourse/plugins/discourse-sitetor-listing/discourse/components/multi-select";

// giữ đồng bộ với SitetorListing::DEMAND_* (plugin.rb) — các giá trị chọn
// TRÙNG TÊN TAG trên site để server đồng bộ tag SEO song song
const DEMAND_TYPES = ["Cần mua", "Cần thuê"];
// gốc cây category nhu cầu (sitetor_listing_demand_categories) → auto-default
// "Loại giao dịch" theo vị trí topic trong cây
const DEMAND_CATEGORY_TYPES = [
  { id: 3344, slug: "can-thue-nha-dat", demandType: "Cần thuê" },
  { id: 3698, slug: "can-mua-bat-dong-san", demandType: "Cần mua" },
];
// giữ đồng bộ với SitetorListing::SeoSlugs::TYPES
const TYPES = [
  "Nhà mặt phố", "Nhà hẻm", "Văn phòng", "Kho, nhà xưởng",
  "Căn hộ, chung cư", "Bán đất", "Tầng thương mại",
];
const PURPOSES = ["Để-ở", "Kinh-doanh", "Đầu-tư"]; // tag group H. Nhu cầu sử dụng
const DIRECTIONS = ["Đông", "Tây", "Nam", "Bắc", "Đông-Bắc", "Đông-Nam", "Tây-Bắc", "Tây-Nam"]; // tag group E. Hướng
const POSITIONS = ["Hẻm", "Khu-compound", "Mặt-tiền", "Ngõ", "Nội-bộ"]; // tag group D. Vị trí
// tag group I. Nghành nghề kinh doanh
const INDUSTRIES = [
  "24h", "Anh-ngữ", "Cafe", "Cây-xăng", "Chuỗi", "Cửa-hàng-thực-phẩm",
  "Điện-thoại", "Game", "Giải-trí", "Giao-hàng", "Giày-dép", "Giặt-ủi",
  "Gym", "Hầm-rựu", "Karaoke", "Mắt-kính", "Ngân-hàng", "Nha-khoa",
  "Nhà-hàng", "Nhà-sách", "Nhà-thuốc", "Nội-thất", "Phòng-công-chứng",
  "Phòng-khám", "Phòng-thu", "Pizza", "Quán-ăn", "Quán-nhậu", "Salon",
  "Sang", "Showroom", "Siêu-thị", "Spa", "Thời-trang", "Thức-ăn-nhanh",
  "Tiệm-net", "Trà-sữa", "Trái-cây", "Trang-sức", "Trường-học",
  "Văn-phòng", "Xe-hơi", "Xe-máy", "Xì-gà",
];
// tag group Views
const VIEWS = [
  "View-công-viên", "View-hồ", "View-hồ-bơi", "View-không-gian-mở",
  "View-nội-khu", "View-núi", "View-sông", "View-toà-nhà",
];

// Form chủ topic nhập thông tin NHU CẦU (Cần mua/Cần thuê) — 1 bộ lọc lưu sẵn:
// range (ngân sách/diện tích/mặt tiền) + multi (nhiều loại/khu vực/hướng/vị trí).
// Custom field demand_* là nguồn chuẩn; server đồng bộ thêm tag SEO song song.
export default class DemandInfoModal extends Component {
  @service siteSettings;
  @service site;

  @tracked loading = true;
  @tracked saving = false;
  @tracked saved = false;

  @tracked fDemandType = "";
  @tracked fPropertyTypes = [];
  @tracked fProvince = [];
  @tracked fDistrict = [];
  @tracked fStreet = [];
  @tracked fBudgetFrom = "";
  @tracked fBudgetTo = "";
  @tracked fBudgetUnit = "million";
  @tracked fAreaFrom = "";
  @tracked fAreaTo = "";
  @tracked fFrontageFrom = "";
  @tracked fFrontageTo = "";
  @tracked fFloorAreaFrom = "";
  @tracked fFloorAreaTo = "";
  @tracked fNumberFloor = "";
  @tracked fPurpose = [];
  @tracked fIndustry = [];
  @tracked fView = [];
  @tracked fDirections = [];
  @tracked fPositions = [];
  @tracked fTitle = "";
  @tracked fNote = "";
  @tracked fCustomerName = "";
  @tracked fCustomerPhone = "";
  @tracked fContactEmail = "";

  // facets địa chỉ từ /listing/facets.json (đường cascade theo quận đã chọn)
  @tracked facets = {};

  demandTypes = DEMAND_TYPES;

  propertyTypeOptions = TYPES.map((v) => ({ value: v }));
  purposeOptions = PURPOSES.map((v) => ({ value: v }));
  industryOptions = INDUSTRIES.map((v) => ({ value: v }));
  viewOptions = VIEWS.map((v) => ({ value: v }));
  directionOptions = DIRECTIONS.map((v) => ({ value: v }));
  positionOptions = POSITIONS.map((v) => ({ value: v }));

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    try {
      const info = await ajax(
        `/listing/demand-info/${this.args.model.topic.id}.json`
      );
      if (Math.max(info.budget_from || 0, info.budget_to || 0) >= 1e9) {
        this.fBudgetUnit = "billion";
      }
      const rate = this.budgetRate;
      this.fBudgetFrom = info.budget_from ? String(info.budget_from / rate) : "";
      this.fBudgetTo = info.budget_to ? String(info.budget_to / rate) : "";
      // chưa lưu demand_type → auto-default theo cây category (Cần thuê/Cần mua)
      this.fDemandType = info.demand_type || this.demandTypeFromCategory();
      this.fPropertyTypes = info.property_types || [];
      this.fProvince = info.provinces || [];
      this.fDistrict = info.districts || [];
      this.fStreet = info.streets || [];
      this.fAreaFrom = info.area_from ? String(info.area_from) : "";
      this.fAreaTo = info.area_to ? String(info.area_to) : "";
      this.fFrontageFrom = info.frontage_from ? String(info.frontage_from) : "";
      this.fFrontageTo = info.frontage_to ? String(info.frontage_to) : "";
      this.fFloorAreaFrom = info.floor_area_from ? String(info.floor_area_from) : "";
      this.fFloorAreaTo = info.floor_area_to ? String(info.floor_area_to) : "";
      this.fNumberFloor = info.number_floor ? String(info.number_floor) : "";
      this.fPurpose = info.purpose || [];
      this.fIndustry = info.industry || [];
      this.fView = info.view || [];
      this.fDirections = info.directions || [];
      this.fPositions = info.positions || [];
      this.fTitle = info.title || "";
      this.fNote = info.note || "";
      this.fCustomerName = info.customer_name || "";
      this.fCustomerPhone = info.customer_phone || "";
      this.fContactEmail = info.contact_email || "";
      await this.loadFacets();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  // options tỉnh/quận/đường từ facets — đường cascade theo quận đã chọn
  // (mirror controllers/listing.js loadFacets)
  async loadFacets() {
    const data = {};
    // District list depends on selected Province(s); Street on District(s).
    if (this.fProvince.length) {
      data.province = this.fProvince.join(",");
    }
    if (this.fDistrict.length) {
      data.district = this.fDistrict.join(",");
    }
    try {
      this.facets = await ajax("/listing/facets.json", { data });
    } catch {
      this.facets = {};
    }
  }

  get provinceOptions() {
    return this.facets.province || [];
  }

  get districtOptions() {
    return this.facets.district || [];
  }

  get streetOptions() {
    return this.facets.street || [];
  }

  // topic thuộc cây "Cần thuê"/"Cần mua" → loại giao dịch mặc định tương ứng
  demandTypeFromCategory() {
    const categories = this.site.categories || [];
    let cat = categories.find(
      (c) => c.id === this.args.model.topic?.category_id
    );
    for (let depth = 0; cat && depth < 6; depth++) {
      const match = DEMAND_CATEGORY_TYPES.find(
        (d) => d.id === cat.id || d.slug === cat.slug
      );
      if (match) {
        return match.demandType;
      }
      cat = categories.find((c) => c.id === cat.parent_category_id);
    }
    return "";
  }

  get budgetRate() {
    if (this.fBudgetUnit === "usd") {
      return this.siteSettings.sitetor_listing_usd_rate || 26000;
    }
    return this.fBudgetUnit === "billion" ? 1e9 : 1e6;
  }

  toVnd(value) {
    if (value === "" || value === null) {
      return "";
    }
    return Number(value) * this.budgetRate;
  }

  @action
  updateField(name, event) {
    this[name] = event.target.value;
  }

  @action
  updateMulti(name, values) {
    this[name] = values;
    if (name === "fProvince") {
      // cascade: đổi tỉnh → nạp lại quận (gộp quận của các tỉnh đã chọn),
      // bỏ quận/đường không còn thuộc tỉnh đã chọn
      this.fDistrict = [];
      this.fStreet = [];
      this.loadFacets();
    } else if (name === "fDistrict") {
      // cascade: đổi quận → nạp lại danh sách đường
      this.fStreet = [];
      this.loadFacets();
    }
  }

  @action
  async save() {
    this.saving = true;
    try {
      await ajax(`/listing/demand-info/${this.args.model.topic.id}.json`, {
        type: "POST",
        data: {
          demand_type: this.fDemandType,
          property_types: JSON.stringify(this.fPropertyTypes),
          provinces: JSON.stringify(this.fProvince),
          districts: JSON.stringify(this.fDistrict),
          streets: JSON.stringify(this.fStreet),
          budget_from: this.toVnd(this.fBudgetFrom),
          budget_to: this.toVnd(this.fBudgetTo),
          area_from: this.fAreaFrom,
          area_to: this.fAreaTo,
          frontage_from: this.fFrontageFrom,
          frontage_to: this.fFrontageTo,
          floor_area_from: this.fFloorAreaFrom,
          floor_area_to: this.fFloorAreaTo,
          number_floor: this.fNumberFloor,
          purpose: JSON.stringify(this.fPurpose),
          industry: JSON.stringify(this.fIndustry),
          view: JSON.stringify(this.fView),
          directions: JSON.stringify(this.fDirections),
          positions: JSON.stringify(this.fPositions),
          title: this.fTitle,
          note: this.fNote,
          customer_name: this.fCustomerName,
          customer_phone: this.fCustomerPhone,
          contact_email: this.fContactEmail,
        },
      });
      this.saved = true;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "sitetor_listing.demand_info_title"}}
      @closeModal={{@closeModal}}
      class="edit-topic-info-modal demand-info-modal"
    >
      <:body>
        {{#if this.loading}}
          <p>…</p>
        {{else if this.saved}}
          <p class="edit-info-saved">✅ {{i18n "sitetor_listing.edit_info_saved"}}</p>
        {{else}}
          <p class="edit-info-hint">{{i18n "sitetor_listing.demand_info_hint"}}</p>

          <div class="edit-info-grid">
            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.demand_type"}}</label>
              <select {{on "change" (fn this.updateField "fDemandType")}}>
                <option value="" selected={{eq this.fDemandType ""}}>—</option>
                {{#each this.demandTypes as |v|}}
                  <option value={{v}} selected={{eq this.fDemandType v}}>{{v}}</option>
                {{/each}}
              </select>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.product_type"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.product_type"}}
                @options={{this.propertyTypeOptions}}
                @selected={{this.fPropertyTypes}}
                @onChange={{fn this.updateMulti "fPropertyTypes"}}
              />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.province"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.province"}}
                @options={{this.provinceOptions}}
                @selected={{this.fProvince}}
                @onChange={{fn this.updateMulti "fProvince"}}
              />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.district"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.district"}}
                @options={{this.districtOptions}}
                @selected={{this.fDistrict}}
                @onChange={{fn this.updateMulti "fDistrict"}}
                @searchable={{true}}
              />
            </div>

            <div class="edit-info-field edit-info-full">
              <label>{{i18n "sitetor_listing.street"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.street"}}
                @options={{this.streetOptions}}
                @selected={{this.fStreet}}
                @onChange={{fn this.updateMulti "fStreet"}}
                @searchable={{true}}
              />
            </div>

            <div class="edit-info-field edit-info-full">
              <label>{{i18n "sitetor_listing.budget"}}</label>
              <div class="edit-info-row">
                <Input @value={{this.fBudgetFrom}} @type="number" min="0" placeholder={{i18n "sitetor_listing.from"}} />
                <Input @value={{this.fBudgetTo}} @type="number" min="0" placeholder={{i18n "sitetor_listing.to"}} />
                <select {{on "change" (fn this.updateField "fBudgetUnit")}}>
                  <option value="million" selected={{eq this.fBudgetUnit "million"}}>{{i18n "sitetor_listing.million"}}</option>
                  <option value="billion" selected={{eq this.fBudgetUnit "billion"}}>{{i18n "sitetor_listing.billion"}}</option>
                  <option value="usd" selected={{eq this.fBudgetUnit "usd"}}>USD</option>
                </select>
              </div>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.area"}} (m²)</label>
              <div class="edit-info-row">
                <Input @value={{this.fAreaFrom}} @type="number" min="0" step="0.1" placeholder={{i18n "sitetor_listing.from"}} />
                <Input @value={{this.fAreaTo}} @type="number" min="0" step="0.1" placeholder={{i18n "sitetor_listing.to"}} />
              </div>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.frontage"}} (m)</label>
              <div class="edit-info-row">
                <Input @value={{this.fFrontageFrom}} @type="number" min="0" step="0.1" placeholder={{i18n "sitetor_listing.from"}} />
                <Input @value={{this.fFrontageTo}} @type="number" min="0" step="0.1" placeholder={{i18n "sitetor_listing.to"}} />
              </div>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.floor_area"}} (m²)</label>
              <div class="edit-info-row">
                <Input @value={{this.fFloorAreaFrom}} @type="number" min="0" step="0.1" placeholder={{i18n "sitetor_listing.from"}} />
                <Input @value={{this.fFloorAreaTo}} @type="number" min="0" step="0.1" placeholder={{i18n "sitetor_listing.to"}} />
              </div>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.number_floor"}}</label>
              <Input @value={{this.fNumberFloor}} @type="number" min="0" step="1" />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.purpose"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.purpose"}}
                @options={{this.purposeOptions}}
                @selected={{this.fPurpose}}
                @onChange={{fn this.updateMulti "fPurpose"}}
              />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.industry"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.industry"}}
                @options={{this.industryOptions}}
                @selected={{this.fIndustry}}
                @onChange={{fn this.updateMulti "fIndustry"}}
                @searchable={{true}}
              />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.direction"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.direction"}}
                @options={{this.directionOptions}}
                @selected={{this.fDirections}}
                @onChange={{fn this.updateMulti "fDirections"}}
              />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.position"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.position"}}
                @options={{this.positionOptions}}
                @selected={{this.fPositions}}
                @onChange={{fn this.updateMulti "fPositions"}}
              />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.view_label"}}</label>
              <MultiSelect
                @label={{i18n "sitetor_listing.view_label"}}
                @options={{this.viewOptions}}
                @selected={{this.fView}}
                @onChange={{fn this.updateMulti "fView"}}
              />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.demand_title_label"}}</label>
              <Input @value={{this.fTitle}} />
            </div>

            <div class="edit-info-field edit-info-full">
              <label>{{i18n "sitetor_listing.note"}}</label>
              <Textarea @value={{this.fNote}} rows="3" />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.customer_name"}}</label>
              <Input @value={{this.fCustomerName}} />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.customer_phone"}}</label>
              <Input @value={{this.fCustomerPhone}} />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.contact_email"}}</label>
              <Input @value={{this.fContactEmail}} @type="email" />
            </div>
          </div>

          <p class="edit-info-note">{{i18n "sitetor_listing.edit_info_note"}}</p>
        {{/if}}
      </:body>
      <:footer>
        {{#unless this.saved}}
          <DButton
            @action={{this.save}}
            @label="sitetor_listing.edit_info_save"
            @disabled={{this.saving}}
            class="btn-primary"
          />
        {{/unless}}
        <DButton @action={{@closeModal}} @label="sitetor_listing.close" />
      </:footer>
    </DModal>
  </template>
}
