import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import MultiSelect from "discourse/plugins/discourse-sitetor-listing/discourse/components/multi-select";

// 25000000 → "25 tr" ; 5500000000 → "5,5 tỷ"
function formatVnd(v) {
  if (!v) {
    return "";
  }
  const n = Number(v);
  if (n >= 1e9) {
    return `${(n / 1e9).toLocaleString("vi-VN", { maximumFractionDigits: 2 })} tỷ`;
  }
  return `${(n / 1e6).toLocaleString("vi-VN", { maximumFractionDigits: 1 })} tr`;
}

// range hiển thị "A – B", "≥ A", "≤ B" (ngôn ngữ trung tính bằng ký hiệu)
function moneyRange(from, to) {
  if (from && to) {
    return `${formatVnd(from)} – ${formatVnd(to)}`;
  }
  if (from) {
    return `≥ ${formatVnd(from)}`;
  }
  if (to) {
    return `≤ ${formatVnd(to)}`;
  }
  return "";
}

function num(n) {
  return Number(n).toLocaleString("vi-VN", { maximumFractionDigits: 1 });
}

function unitRange(from, to, unit) {
  if (from && to) {
    return `${num(from)} – ${num(to)} ${unit}`;
  }
  if (from) {
    return `≥ ${num(from)} ${unit}`;
  }
  if (to) {
    return `≤ ${num(to)} ${unit}`;
  }
  return "";
}

function frontageMin(v) {
  return v ? `≥ ${num(v)} m` : "";
}

function joinList(arr) {
  return (arr || []).join(", ");
}

// khu vực = quận/huyện + tỉnh/thành (bỏ trùng, ghép bằng " · ")
function regionOf(t) {
  const parts = [...(t.districts || []), ...(t.provinces || [])];
  return [...new Set(parts)].join(" · ");
}

export default <template>
  <div class="sitetor-demand">
    {{#if @controller.landingName}}
      <h1 class="demand-landing-h1">{{i18n "sitetor_listing.demand_landing_h1" name=@controller.landingName}}</h1>
      <p class="demand-crumb">
        <a href="/demand">{{i18n "sitetor_listing.demand_page_title"}}</a>
        <span>›</span>
        {{@controller.landingName}}
      </p>
    {{else}}
      <h1><a href="/demand" class="listing-home-link">{{i18n "sitetor_listing.demand_page_title"}}</a></h1>
    {{/if}}

    <div class="demand-layout demand-layout--stacked">
      <details class="demand-filterbar" open>
        <summary class="demand-filterbar__summary">{{i18n "sitetor_listing.filters"}}</summary>
        <div class="demand-filterbar__grid">
        <div class="demand-filter-group listing-filter-q">
          <Input
            @value={{@controller.fQ}}
            placeholder={{i18n "sitetor_listing.search_hint"}}
            {{on "keydown" @controller.onQKeydown}}
          />
        </div>

        <MultiSelect
          @label={{i18n "sitetor_listing.demand_type"}}
          @options={{@controller.facets.demand_type}}
          @selected={{@controller.sDemandType}}
          @onChange={{fn @controller.setSelection "sDemandType"}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.product_type"}}
          @options={{@controller.facets.property_types}}
          @selected={{@controller.sPropertyTypes}}
          @onChange={{fn @controller.setSelection "sPropertyTypes"}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.province"}}
          @options={{@controller.facets.province}}
          @selected={{@controller.sProvinces}}
          @onChange={{fn @controller.setSelection "sProvinces"}}
          @searchable={{true}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.district"}}
          @options={{@controller.facets.district}}
          @selected={{@controller.sDistricts}}
          @onChange={{fn @controller.setSelection "sDistricts"}}
          @searchable={{true}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.purpose"}}
          @options={{@controller.facets.purpose}}
          @selected={{@controller.sPurpose}}
          @onChange={{fn @controller.setSelection "sPurpose"}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.industry"}}
          @options={{@controller.facets.industry}}
          @selected={{@controller.sIndustry}}
          @onChange={{fn @controller.setSelection "sIndustry"}}
          @searchable={{true}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.direction"}}
          @options={{@controller.facets.direction}}
          @selected={{@controller.sDirections}}
          @onChange={{fn @controller.setSelection "sDirections"}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.position"}}
          @options={{@controller.facets.position}}
          @selected={{@controller.sPositions}}
          @onChange={{fn @controller.setSelection "sPositions"}}
        />

        <div class="demand-filter-group">
          <label>{{i18n "sitetor_listing.budget"}}</label>
          <div class="demand-range">
            <Input @value={{@controller.fBudgetMin}} @type="number" placeholder={{i18n "sitetor_listing.from"}} />
            <span>–</span>
            <Input @value={{@controller.fBudgetMax}} @type="number" placeholder={{i18n "sitetor_listing.to"}} />
          </div>
          <select {{on "change" (fn @controller.updateField "fBudgetUnit")}}>
            <option value="million" selected={{eq @controller.fBudgetUnit "million"}}>{{i18n "sitetor_listing.million"}}</option>
            <option value="billion" selected={{eq @controller.fBudgetUnit "billion"}}>{{i18n "sitetor_listing.billion"}}</option>
            <option value="usd" selected={{eq @controller.fBudgetUnit "usd"}}>USD</option>
          </select>
        </div>

        <div class="demand-filter-group">
          <label>{{i18n "sitetor_listing.demand_land_area"}} (m²)</label>
          <div class="demand-range">
            <Input @value={{@controller.fAreaMin}} @type="number" placeholder="min" />
            <span>–</span>
            <Input @value={{@controller.fAreaMax}} @type="number" placeholder="max" />
          </div>
        </div>

        <div class="demand-filter-group">
          <label>{{i18n "sitetor_listing.demand_floor_area"}} (m²)</label>
          <div class="demand-range">
            <Input @value={{@controller.fFloorMin}} @type="number" placeholder="min" />
            <span>–</span>
            <Input @value={{@controller.fFloorMax}} @type="number" placeholder="max" />
          </div>
        </div>

        <div class="demand-filter-group">
          <label>{{i18n "sitetor_listing.frontage"}} (m)</label>
          <div class="demand-range">
            <Input @value={{@controller.fFrontageMin}} @type="number" placeholder="min" />
            <span>–</span>
            <Input @value={{@controller.fFrontageMax}} @type="number" placeholder="max" />
          </div>
        </div>

        <div class="demand-filter-group">
          <label>{{i18n "sitetor_listing.sort_by"}}</label>
          <select {{on "change" (fn @controller.updateField "fSort")}}>
            <option value="new" selected={{eq @controller.fSort "new"}}>{{i18n "sitetor_listing.newest"}}</option>
            <option value="budget_asc" selected={{eq @controller.fSort "budget_asc"}}>{{i18n "sitetor_listing.budget_asc"}}</option>
            <option value="budget_desc" selected={{eq @controller.fSort "budget_desc"}}>{{i18n "sitetor_listing.budget_desc"}}</option>
            <option value="area_desc" selected={{eq @controller.fSort "area_desc"}}>{{i18n "sitetor_listing.area_desc"}}</option>
          </select>
        </div>

        <div class="demand-actions">
          <DButton
            @action={{@controller.applyFilter}}
            @icon="magnifying-glass"
            @label="sitetor_listing.apply_filter"
            class="btn-primary"
          />
          <DButton @action={{@controller.resetFilter}} @label="sitetor_listing.reset_filter" />
        </div>
        </div>
      </details>

      <div class="demand-content">
        <p class="listing-total">
          {{i18n "sitetor_listing.demand_total_found" count=@controller.total}}
          · {{i18n "sitetor_listing.page_of" page=@controller.currentPage total=@controller.totalPages}}
        </p>

        <div class="demand-cards">
          {{#each @controller.topics as |t|}}
            <div class="demand-card">
              <div class="demand-card__head">
                <a class="demand-card__title" href="/t/{{t.slug}}/{{t.id}}">{{t.title}}</a>
                {{#if t.demand_type}}
                  <span class="demand-card__badge">{{t.demand_type}}</span>
                {{/if}}
              </div>

              <div class="demand-card__body">
                {{#if t.industry.length}}
                  <div class="demand-card__row">
                    <span class="demand-card__k">{{i18n "sitetor_listing.industry"}}</span>
                    <span class="demand-card__v">{{joinList t.industry}}</span>
                  </div>
                {{/if}}
                {{#if t.property_types.length}}
                  <div class="demand-card__row">
                    <span class="demand-card__k">{{i18n "sitetor_listing.product_type"}}</span>
                    <span class="demand-card__v">{{joinList t.property_types}}</span>
                  </div>
                {{/if}}
                {{#if (moneyRange t.budget_from t.budget_to)}}
                  <div class="demand-card__row">
                    <span class="demand-card__k">{{i18n "sitetor_listing.budget"}}</span>
                    <span class="demand-card__v demand-card__strong">{{moneyRange t.budget_from t.budget_to}}</span>
                  </div>
                {{/if}}
                {{#if (unitRange t.area_from t.area_to "m²")}}
                  <div class="demand-card__row">
                    <span class="demand-card__k">{{i18n "sitetor_listing.demand_land_area"}}</span>
                    <span class="demand-card__v">{{unitRange t.area_from t.area_to "m²"}}</span>
                  </div>
                {{/if}}
                {{#if (unitRange t.floor_area_from t.floor_area_to "m²")}}
                  <div class="demand-card__row">
                    <span class="demand-card__k">{{i18n "sitetor_listing.demand_floor_area"}}</span>
                    <span class="demand-card__v">{{unitRange t.floor_area_from t.floor_area_to "m²"}}</span>
                  </div>
                {{/if}}
                {{#if (frontageMin t.frontage_from)}}
                  <div class="demand-card__row">
                    <span class="demand-card__k">{{i18n "sitetor_listing.frontage"}}</span>
                    <span class="demand-card__v">{{frontageMin t.frontage_from}}</span>
                  </div>
                {{/if}}
                {{#if (regionOf t)}}
                  <div class="demand-card__row">
                    <span class="demand-card__k">{{i18n "sitetor_listing.region"}}</span>
                    <span class="demand-card__v">{{regionOf t}}</span>
                  </div>
                {{/if}}
              </div>

              <div class="demand-card__foot">
                {{#if @controller.currentUser}}
                  <DButton
                    @action={{fn @controller.openRecommend t}}
                    @icon="reply"
                    @label="sitetor_listing.recommend"
                    class="btn-primary btn-small"
                  />
                {{/if}}
                <a class="demand-card__link" href="/t/{{t.slug}}/{{t.id}}">{{i18n "sitetor_listing.view_detail"}}</a>
              </div>
            </div>
          {{else}}
            <p class="demand-empty">{{i18n "sitetor_listing.demand_no_results"}}</p>
          {{/each}}
        </div>

        <div class="listing-paging">
          <DButton
            @action={{@controller.prevPage}}
            @disabled={{unless @controller.hasPrev true}}
            @label="sitetor_listing.prev"
          />
          <span class="listing-page-list">
            {{#each @controller.pageList as |p|}}
              {{#if p.current}}
                <span class="listing-page listing-page-current">{{p.num}}</span>
              {{else}}
                <button
                  type="button"
                  class="listing-page"
                  {{on "click" (fn @controller.goPage p.num)}}
                >{{p.num}}</button>
              {{/if}}
            {{/each}}
          </span>
          <DButton
            @action={{@controller.nextPage}}
            @disabled={{unless @controller.hasNext true}}
            @label="sitetor_listing.next"
          />
          <span class="listing-goto">
            {{i18n "sitetor_listing.go_to_page"}}
            <Input
              @value={{@controller.fGotoPage}}
              @type="number"
              min="1"
              {{on "input" @controller.updateGotoPage}}
            />
            <DButton @action={{@controller.gotoPage}} @label="sitetor_listing.go" class="btn-small" />
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
