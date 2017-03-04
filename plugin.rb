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
    skip_before_filter :preload_json, :check_xhr

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

      @output = Rails.cache.fetch("sitemap/index", expires_in: 24.hours) do
        count = topics_query.count
        sitemap_size = SiteSetting.sitemap_topics_per_page
        @size = count / sitemap_size
        @size += 1 if count % sitemap_size > 0
        @lastmod = Time.now
        1.upto(@size) do |i|
          Rails.cache.delete("sitemap/#{i}")
        end
        if @size > 1
          render :index, content_type: 'text/xml; charset=UTF-8'
        else
          sitemap(1)
        end
      end
      render :text => @output[0], content_type: 'text/xml; charset=UTF-8' unless performed?
    end

    def default
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      page = Integer(params.require(:page))
      sitemap(page)
    end

    def sitemap(page)
      sitemap_size = SiteSetting.sitemap_topics_per_page
      offset = (page - 1) * sitemap_size

      @output = Rails.cache.fetch("sitemap/#{page}", expires_in: 24.hours) do
        @topics = Array.new
        topics_query.limit(sitemap_size).offset(offset).pluck(:id, :slug, :last_posted_at, :updated_at).each do |t|
          t[2] = t[3] if t[2].nil?
          @topics.push t
        end
        render :default, content_type: 'text/xml; charset=UTF-8'
      end
      render :text => @output[0], content_type: 'text/xml; charset=UTF-8' unless performed?
      return @output
    end

    def news
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      @output = Rails.cache.fetch("sitemap/news", expires_in: 5.minutes) do
        dlocale = SiteSetting.default_locale.downcase
        @locale = dlocale.gsub(/_.*/, '')
        @locale = dlocale.sub('_', '-') if @locale === "zh"
        @topics = topics_query(72.hours.ago).pluck(:id, :title, :slug, :created_at)
        render :news, content_type: 'text/xml; charset=UTF-8'
      end
      render :text => @output[0], content_type: 'text/xml; charset=UTF-8' unless performed?
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
