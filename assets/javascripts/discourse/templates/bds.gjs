import { Input } from "@ember/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

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

export default <template>
  <div class="sitetor-bds">
    <h1>{{i18n "sitetor_bds.title"}}</h1>

    <div class="bds-filters">
      <div class="bds-filter-group">
        <label>{{i18n "sitetor_bds.gia"}} ({{i18n "sitetor_bds.trieu"}})</label>
        <Input @value={{@controller.fGiaMin}} @type="number" placeholder="min" />
        <span>–</span>
        <Input @value={{@controller.fGiaMax}} @type="number" placeholder="max" />
      </div>

      <div class="bds-filter-group">
        <label>{{i18n "sitetor_bds.mat_tien"}} (m)</label>
        <Input @value={{@controller.fMtMin}} @type="number" placeholder="min" />
        <span>–</span>
        <Input @value={{@controller.fMtMax}} @type="number" placeholder="max" />
      </div>

      <div class="bds-filter-group">
        <label>{{i18n "sitetor_bds.dien_tich"}} (m²)</label>
        <Input @value={{@controller.fDtMin}} @type="number" placeholder="min" />
        <span>–</span>
        <Input @value={{@controller.fDtMax}} @type="number" placeholder="max" />
      </div>

      <DButton
        @action={{@controller.applyFilter}}
        @icon="magnifying-glass"
        @label="sitetor_bds.loc"
        class="btn-primary"
      />
      <DButton @action={{@controller.resetFilter}} @label="sitetor_bds.xoa_loc" />
    </div>

    <p class="bds-total">{{i18n "sitetor_bds.tong" count=@controller.total}}</p>

    <div class="bds-table-wrap">
      <table class="bds-table">
        <thead>
          <tr>
            <th>{{i18n "sitetor_bds.tin"}}</th>
            <th>{{i18n "sitetor_bds.gia"}}</th>
            <th>{{i18n "sitetor_bds.mat_tien"}}</th>
            <th>{{i18n "sitetor_bds.dien_tich"}}</th>
            <th>{{i18n "sitetor_bds.tags"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.topics as |t|}}
            <tr>
              <td class="bds-title">
                <a href="/t/{{t.slug}}/{{t.id}}">{{t.title}}</a>
              </td>
              <td class="bds-num">{{formatGia t.gia}}</td>
              <td class="bds-num">{{orDash t.mat_tien}}</td>
              <td class="bds-num">{{orDash t.dien_tich}}</td>
              <td class="bds-tags">
                {{#each t.tags as |tag|}}<span class="bds-tag">{{tag}}</span>{{/each}}
              </td>
            </tr>
          {{else}}
            <tr><td colspan="5">{{i18n "sitetor_bds.khong_co"}}</td></tr>
          {{/each}}
        </tbody>
      </table>
    </div>

    <div class="bds-paging">
      <DButton
        @action={{@controller.prevPage}}
        @disabled={{unless @controller.hasPrev true}}
        @label="sitetor_bds.truoc"
      />
      <span>{{i18n "sitetor_bds.trang" page=@controller.page}}</span>
      <DButton
        @action={{@controller.nextPage}}
        @disabled={{unless @controller.hasNext true}}
        @label="sitetor_bds.sau"
      />
    </div>
  </div>
</template>
