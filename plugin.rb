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

  class DiscourseSitemap::SitemapController < ::ApplicationController
    layout false
    skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required

    SITEMAP_SIZE = 50000.freeze

    def topics_query(since = nil)
      category_ids = Category.where(read_restricted: false).pluck(:id)
      query = Topic.where(category_id: category_ids, visible: true)
      query = query.created_since(since) unless since.nil?
      query = query.order(created_at: :desc)
      query
    end

    def index
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      @size, @lastmod = Rails.cache.fetch("sitemap", expires_in: 24.hours) do
        count = topics_query.count
        size = count / SITEMAP_SIZE
        size += 1 if count % SITEMAP_SIZE > 0
        time = Time.now
        1.upto(size) do |i|
          Rails.cache.delete("sitemap/#{i}")
        end
        [size, time]
      end
      if @size > 1
        render :index, content_type: 'text/xml; charset=UTF-8'
      else
        sitemap(1)
      end
    end

    def default
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      page = Integer(params.require(:page))
      sitemap(page)
    end

    def sitemap(page)
      offset = (page - 1) * SITEMAP_SIZE

      @topics = Rails.cache.fetch("sitemap/#{page}", expires_in: 24.hours) do
        topics = Array.new
        topics_query.limit(SITEMAP_SIZE).offset(offset).select(:id, :slug, :last_posted_at, :updated_at).each do |t|
          t.last_posted_at = t.updated_at if t.last_posted_at.nil?
          topics.push t
        end
      end
      render :default, content_type: 'text/xml; charset=UTF-8'
    end

    def news
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      @topics = Rails.cache.fetch("sitemap/news", expires_in: 5.minutes) do
        topics_query(72.hours.ago).select(:id, :title, :slug, :created_at)
      end
      render :news, content_type: 'text/xml; charset=UTF-8'
    end
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSitemap::Engine, at: "/sitemap"
  end

  DiscourseSitemap::Engine.routes.draw do
    get ".xml" => "sitemap#index"
    get "news.xml" => "sitemap#news"
    get ":page.xml" => "sitemap#default"
  end

end
