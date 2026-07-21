import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DemandRoute extends DiscourseRoute {
  @service documentTitle;

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
    industry: { refreshModel: true },
  };

  model(params) {
    return ajax("/listing/demand-filter.json", { data: params });
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    // rời trang landing ngành nghề → bỏ H1 riêng; tô chip theo filter industry hiện tại
    controller.landingName = null;
    controller.activeIndustry = controller.industry || null;
    if (!controller.facets?.province) {
      controller.loadFacets();
    }
  }
}
