# name: Discourse Sitemap
# about:
# version: 1.0
# authors: DiscourseHosting.com
# url: https://github.com/discoursehosting/discourse-sitemap

PLUGIN_NAME = "discourse-sitemap".freeze

enabled_site_setting :sitemap_enabled

after_initialize do

  module ::DiscourseSitemap
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseSitemap
    end
  end

  require_dependency "application_controller"

  class ::SitemapController < ::ApplicationController
    layout false
    skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required

    def topics_query(since = nil)
      category_ids = Category.where(read_restricted: false).pluck(:id)
      query = Topic.where(category_id: category_ids, visible: true)
      query = query.created_since(since) unless since.nil?
      query = query.order(created_at: :desc)
      query
    end

    def default
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      @topics = Array.new
      topics_query.select(:id, :slug, :last_posted_at, :updated_at).each do |t|
        t.last_posted_at = t.updated_at if t.last_posted_at.nil?
        @topics.push t
      end
      render :default, content_type: 'text/xml; charset=UTF-8'
    end

    def news
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      @topics = topics_query(72.hours.ago).select(:id, :title, :slug, :created_at)
      render :news, content_type: 'text/xml; charset=UTF-8'
    end
  end

  Discourse::Application.routes.prepend do
    get "sitemap.xml" => "sitemap#default"
    get "newssitemap.xml" => "sitemap#news"
  end

end
