import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

// Landing 1 ngành nghề (/demand/:slug). Dùng lại controller + template "demand";
// chiều industry ghim theo slug (không nằm trong query string). Các filter/paging
// còn lại vẫn refresh model như trang /demand.
export default class DemandTagRoute extends DiscourseRoute {
  @service documentTitle;

  controllerName = "demand";
  templateName = "demand";

  queryParams = {
    q: { refreshModel: true },
    budget_min: { refreshModel: true },
    budget_max: { refreshModel: true },
    area_min: { refreshModel: true },
    area_max: { refreshModel: true },
    frontage_min: { refreshModel: true },
    frontage_max: { refreshModel: true },
    floor_min: { refreshModel: true },
    floor_max: { refreshModel: true },
    category_id: { refreshModel: true },
    sort: { refreshModel: true },
    page: { refreshModel: true },
    demand_type: { refreshModel: true },
    property_types: { refreshModel: true },
    provinces: { refreshModel: true },
    districts: { refreshModel: true },
    directions: { refreshModel: true },
    positions: { refreshModel: true },
    purpose: { refreshModel: true },
  };

  async model(params) {
    const facets = await ajax("/listing/demand-facets.json");
    const entry = (facets.industry || []).find((o) => o.slug === params.slug);
    const name = entry?.value;

    const data = { ...params };
    delete data.slug;
    data.industry = name;

    const result = await ajax("/listing/demand-filter.json", { data });
    result._facets = facets;
    result._industry = name;
    return result;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.facets = model._facets || {};
    controller.activeIndustry = model._industry || null;
    controller.sIndustry = model._industry ? [model._industry] : [];
    controller.landingName = model._industry
      ? model._industry.replaceAll("-", " ")
      : null;
    if (controller.landingName) {
      this.documentTitle.setTitle(
        `Nhu cầu thuê & mua mặt bằng ${controller.landingName}`
      );
    }
  }
}
