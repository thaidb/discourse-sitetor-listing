import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class ListingRoute extends DiscourseRoute {
  queryParams = {
    gia_min: { refreshModel: true },
    gia_max: { refreshModel: true },
    mt_min: { refreshModel: true },
    mt_max: { refreshModel: true },
    dt_min: { refreshModel: true },
    dt_max: { refreshModel: true },
    category_id: { refreshModel: true },
    page: { refreshModel: true },
  };

  model(params) {
    return ajax("/listing/filter.json", { data: params });
  }
}
