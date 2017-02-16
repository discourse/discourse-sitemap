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

    def default
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      @topics = Array.new
      Category.where(read_restricted: false).each do |c|
        topics = c.topics.visible
        topics.order(:created_at).reverse_order.each do |t|
          t.last_posted_at = t.updated_at if t.last_posted_at.nil?
          @topics.push t
        end
      end
      render :default, content_type: 'text/xml; charset=UTF-8'
    end

    def news
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      @topics = Array.new
      Category.where(read_restricted: false).each do |c|
        topics = c.topics.visible
        topics.created_since(72.hours.ago).order(:created_at).reverse_order.each do |t|
          t.last_posted_at = t.updated_at if t.last_posted_at.nil?
          @topics.push t
        end
      end
      render :news, content_type: 'text/xml; charset=UTF-8'
    end
  end

  Discourse::Application.routes.prepend do
    get "newssitemap.xml" => "sitemap#news"
    get "sitemap.xml" => "sitemap#default"
  end

end
