import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class ListingRoute extends DiscourseRoute {
  queryParams = {
    q: { refreshModel: true },
    gia_min: { refreshModel: true },
    gia_max: { refreshModel: true },
    mt_min: { refreshModel: true },
    mt_max: { refreshModel: true },
    dt_min: { refreshModel: true },
    dt_max: { refreshModel: true },
    category_id: { refreshModel: true },
    sort: { refreshModel: true },
    page: { refreshModel: true },
    loai: { refreshModel: true },
    vi_tri: { refreshModel: true },
    huong: { refreshModel: true },
    tinh: { refreshModel: true },
    quan: { refreshModel: true },
    phuong: { refreshModel: true },
    duong: { refreshModel: true },
  };

  model(params) {
    return ajax("/listing/filter.json", { data: params });
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    // nạp options cho các dropdown multi-select (1 lần khi vào trang)
    if (!controller.facets?.loai) {
      controller.loadFacets();
    }
  }
}
