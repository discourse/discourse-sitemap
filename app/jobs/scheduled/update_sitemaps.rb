# frozen_string_literal: true

module ::Jobs
  class UpdateSitemaps < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      DiscourseSitemap::Sitemap.update! if SiteSetting.sitemap_enabled
    end
  end
end
