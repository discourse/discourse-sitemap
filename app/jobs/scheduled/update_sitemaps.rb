# frozen_string_literal: true

module ::Jobs
  class UpdateSitemaps < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      return if SiteSetting.respond_to?(:publish_sitemaps)

      DiscourseSitemap::Sitemap.update! if SiteSetting.sitemap_enabled
    end
  end
end
