# frozen_string_literal: true

module SitetorFilter
  # Full page load /listing: render app shell rỗng để Ember boot và
  # route "listing" phía client đảm nhận phần còn lại (pattern styleguide).
  class PageController < ::ApplicationController
    requires_plugin SitetorFilter::PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      render "default/empty"
    end
  end
end
