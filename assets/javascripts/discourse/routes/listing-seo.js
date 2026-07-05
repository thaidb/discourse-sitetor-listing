import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

// Trang SEO cho người thật: parse path server-side qua filter.json?path=…,
// render cùng giao diện /listing với bộ lọc đã gắn sẵn.
export default class ListingSeoRoute extends DiscourseRoute {
  model(params) {
    return ajax("/listing/filter.json", { data: { path: params.filters } });
  }

  titleToken() {
    return this.modelFor(this.routeName)?.seo_title;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.prefillFromParsed(model.parsed);
  }
}
