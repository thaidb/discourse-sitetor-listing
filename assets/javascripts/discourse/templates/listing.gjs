import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import BdsMultiSelect from "discourse/plugins/discourse-sitetor-listing/discourse/components/bds-multi-select";

// 25000000 → "25 tr" ; 5500000000 → "5,5 tỷ"
function formatGia(vnd) {
  if (!vnd) {
    return "—";
  }
  const n = Number(vnd);
  if (n >= 1e9) {
    return `${(n / 1e9).toLocaleString("vi-VN", { maximumFractionDigits: 2 })} tỷ`;
  }
  return `${(n / 1e6).toLocaleString("vi-VN", { maximumFractionDigits: 1 })} tr`;
}

function orDash(v) {
  return v ?? "—";
}

function eq(a, b) {
  return a === b;
}

export default <template>
  <div class="sitetor-listing">
    {{! tiêu đề là link reset về /listing gốc }}
    <h1><a href="/listing" class="bds-home-link">{{i18n "sitetor_listing.title"}}</a></h1>

    <div class="bds-filters">
      <div class="bds-filter-row">
        <div class="bds-filter-group bds-filter-q">
          <Input
            @value={{@controller.fQ}}
            placeholder={{i18n "sitetor_listing.tu_khoa"}}
            {{on "keydown" @controller.onQKeydown}}
          />
        </div>

        <div class="bds-filter-group">
          <label>{{i18n "sitetor_listing.loai_tin"}}</label>
          <select {{on "change" (fn @controller.updateField "fCategoryId")}}>
            <option value="" selected={{eq @controller.fCategoryId ""}}>
              {{i18n "sitetor_listing.tat_ca"}}
            </option>
            {{#each @controller.categoryOptions as |c|}}
              <option value={{c.id}} selected={{eq @controller.fCategoryId c.id}}>{{c.name}}</option>
            {{/each}}
          </select>
        </div>

        <BdsMultiSelect
          @label={{i18n "sitetor_listing.loai_san_pham"}}
          @options={{@controller.facets.loai}}
          @selected={{@controller.sLoai}}
          @onChange={{fn @controller.setSelection "sLoai"}}
        />
        <BdsMultiSelect
          @label={{i18n "sitetor_listing.tinh_thanh"}}
          @options={{@controller.facets.tinh}}
          @selected={{@controller.sTinh}}
          @onChange={{fn @controller.setSelection "sTinh"}}
        />
        <BdsMultiSelect
          @label={{i18n "sitetor_listing.quan_huyen"}}
          @options={{@controller.facets.quan}}
          @selected={{@controller.sQuan}}
          @onChange={{fn @controller.setSelection "sQuan"}}
          @searchable={{true}}
        />
        <BdsMultiSelect
          @label={{i18n "sitetor_listing.phuong_xa"}}
          @options={{@controller.facets.phuong}}
          @selected={{@controller.sPhuong}}
          @onChange={{fn @controller.setSelection "sPhuong"}}
          @searchable={{true}}
        />
        <BdsMultiSelect
          @label={{i18n "sitetor_listing.duong_pho"}}
          @options={{@controller.facets.duong}}
          @selected={{@controller.sDuong}}
          @onChange={{fn @controller.setSelection "sDuong"}}
          @searchable={{true}}
        />
        <BdsMultiSelect
          @label={{i18n "sitetor_listing.vi_tri"}}
          @options={{@controller.facets.vi_tri}}
          @selected={{@controller.sViTri}}
          @onChange={{fn @controller.setSelection "sViTri"}}
        />
        <BdsMultiSelect
          @label={{i18n "sitetor_listing.huong"}}
          @options={{@controller.facets.huong}}
          @selected={{@controller.sHuong}}
          @onChange={{fn @controller.setSelection "sHuong"}}
        />
      </div>

      <div class="bds-filter-row">
        <div class="bds-filter-group">
          <label>{{i18n "sitetor_listing.gia"}}</label>
          <Input @value={{@controller.fGiaMin}} @type="number" placeholder={{i18n "sitetor_listing.tu"}} />
          <span>–</span>
          <Input @value={{@controller.fGiaMax}} @type="number" placeholder={{i18n "sitetor_listing.den"}} />
          <select {{on "change" (fn @controller.updateField "fGiaUnit")}}>
            <option value="trieu" selected={{eq @controller.fGiaUnit "trieu"}}>{{i18n "sitetor_listing.trieu"}}</option>
            <option value="ty" selected={{eq @controller.fGiaUnit "ty"}}>{{i18n "sitetor_listing.ty"}}</option>
            <option value="usd" selected={{eq @controller.fGiaUnit "usd"}}>USD</option>
          </select>
        </div>

        <div class="bds-filter-group">
          <label>{{i18n "sitetor_listing.mat_tien"}} (m)</label>
          <Input @value={{@controller.fMtMin}} @type="number" placeholder="min" />
          <span>–</span>
          <Input @value={{@controller.fMtMax}} @type="number" placeholder="max" />
        </div>

        <div class="bds-filter-group">
          <label>{{i18n "sitetor_listing.dien_tich"}} (m²)</label>
          <Input @value={{@controller.fDtMin}} @type="number" placeholder="min" />
          <span>–</span>
          <Input @value={{@controller.fDtMax}} @type="number" placeholder="max" />
        </div>

        <div class="bds-filter-group">
          <label>{{i18n "sitetor_listing.sap_xep"}}</label>
          <select {{on "change" (fn @controller.updateField "fSort")}}>
            <option value="new" selected={{eq @controller.fSort "new"}}>{{i18n "sitetor_listing.moi_nhat"}}</option>
            <option value="price_asc" selected={{eq @controller.fSort "price_asc"}}>{{i18n "sitetor_listing.gia_tang"}}</option>
            <option value="price_desc" selected={{eq @controller.fSort "price_desc"}}>{{i18n "sitetor_listing.gia_giam"}}</option>
            <option value="area_desc" selected={{eq @controller.fSort "area_desc"}}>{{i18n "sitetor_listing.dt_lon"}}</option>
          </select>
        </div>

        <DButton
          @action={{@controller.applyFilter}}
          @icon="magnifying-glass"
          @label="sitetor_listing.loc"
          class="btn-primary"
        />
        <DButton @action={{@controller.resetFilter}} @label="sitetor_listing.xoa_loc" />
      </div>
    </div>

    <p class="bds-total">
      {{i18n "sitetor_listing.tong" count=@controller.total}}
      · {{i18n "sitetor_listing.trang_x_tren_y" page=@controller.currentPage total=@controller.totalPages}}
      {{#if @controller.model.seo_base}}
        · <a class="bds-seo-link" href="/listing/{{@controller.model.seo_base}}">
          🔗 {{i18n "sitetor_listing.trang_seo"}}
        </a>
      {{/if}}
    </p>

    <div class="bds-table-wrap">
      <table class="bds-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>{{i18n "sitetor_listing.loai_san_pham"}}</th>
            <th>{{i18n "sitetor_listing.so_nha"}}</th>
            <th>{{i18n "sitetor_listing.duong_pho"}}</th>
            <th>{{i18n "sitetor_listing.phuong_xa"}}</th>
            <th>{{i18n "sitetor_listing.quan_huyen"}}</th>
            <th>{{i18n "sitetor_listing.gia"}}</th>
            <th>{{i18n "sitetor_listing.mat_tien"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.topics as |t|}}
            <tr>
              <td class="bds-num">
                <a href="/t/{{t.slug}}/{{t.id}}" title={{t.title}}>{{t.id}}</a>
              </td>
              <td>{{orDash t.loai}}</td>
              <td class="bds-num">{{orDash t.so_nha}}</td>
              <td><a href="/t/{{t.slug}}/{{t.id}}" title={{t.title}}>{{orDash t.duong}}</a></td>
              <td>{{orDash t.phuong}}</td>
              <td>{{orDash t.quan}}</td>
              <td class="bds-num">{{formatGia t.gia}}</td>
              <td class="bds-num">{{orDash t.mat_tien}}</td>
            </tr>
          {{else}}
            <tr><td colspan="8">{{i18n "sitetor_listing.khong_co"}}</td></tr>
          {{/each}}
        </tbody>
      </table>
    </div>

    {{! phân trang nhảy bước: 1,2,3,4,5 ... 10,15,20 ... 100,200 ... n }}
    <div class="bds-paging">
      <DButton
        @action={{@controller.prevPage}}
        @disabled={{unless @controller.hasPrev true}}
        @label="sitetor_listing.truoc"
      />
      <span class="bds-page-list">
        {{#each @controller.pageList as |p|}}
          {{#if p.current}}
            <span class="bds-page bds-page-current">{{p.num}}</span>
          {{else}}
            <button
              type="button"
              class="bds-page"
              {{on "click" (fn @controller.goPage p.num)}}
            >{{p.num}}</button>
          {{/if}}
        {{/each}}
      </span>
      <DButton
        @action={{@controller.nextPage}}
        @disabled={{unless @controller.hasNext true}}
        @label="sitetor_listing.sau"
      />
    </div>
  </div>
</template>
