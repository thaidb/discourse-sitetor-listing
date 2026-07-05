import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

// Dropdown checkbox multi-select thuần (details/summary — không phụ thuộc
// select-kit), có ô tìm nhanh cho danh sách dài (đường phố ~500 mục).
// args: @label, @options [{value, count}], @selected [string], @onChange(values)
export default class BdsMultiSelect extends Component {
  @tracked filterText = "";

  get filtered() {
    const opts = this.args.options || [];
    const q = this.filterText.trim().toLowerCase();
    return q ? opts.filter((o) => o.value.toLowerCase().includes(q)) : opts;
  }

  get selectedCount() {
    return (this.args.selected || []).length;
  }

  isChecked = (value) => (this.args.selected || []).includes(value);

  @action
  toggle(value) {
    const cur = this.args.selected || [];
    const next = cur.includes(value)
      ? cur.filter((v) => v !== value)
      : [...cur, value];
    this.args.onChange(next);
  }

  @action
  updateFilter(event) {
    this.filterText = event.target.value;
  }

  <template>
    <details class="bds-ms">
      <summary>
        {{@label}}{{#if this.selectedCount}}
          <span class="bds-ms-count">{{this.selectedCount}}</span>
        {{/if}}
        <span class="bds-ms-caret">▾</span>
      </summary>
      <div class="bds-ms-panel">
        {{#if @searchable}}
          <input
            type="text"
            class="bds-ms-search"
            placeholder={{i18n "sitetor_filter.tim_nhanh"}}
            {{on "input" this.updateFilter}}
          />
        {{/if}}
        <ul>
          {{#each this.filtered as |o|}}
            <li>
              <label>
                <input
                  type="checkbox"
                  checked={{this.isChecked o.value}}
                  {{on "change" (fn this.toggle o.value)}}
                />
                <span class="bds-ms-value">{{o.value}}</span>
                <span class="bds-ms-c">({{o.count}})</span>
              </label>
            </li>
          {{else}}
            <li class="bds-ms-empty">{{i18n "sitetor_filter.khong_co_lua_chon"}}</li>
          {{/each}}
        </ul>
      </div>
    </details>
  </template>
}
