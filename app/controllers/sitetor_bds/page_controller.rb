# frozen_string_literal: true

module SitetorBds
  # Full page load /bds: render app shell rỗng để Ember boot và
  # route "bds" phía client đảm nhận phần còn lại (pattern styleguide).
  class PageController < ::ApplicationController
    requires_plugin SitetorBds::PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      render "default/empty"
    end
  end
end
