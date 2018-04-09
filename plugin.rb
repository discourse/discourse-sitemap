# name: Discourse Sitemap
# about:
# version: 1.1
# authors: DiscourseHosting.com, vinothkannans
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
    skip_before_action :preload_json, :check_xhr

    def topics_query(since = nil)
      category_ids = Category.where(read_restricted: false).pluck(:id)
      query = Topic.where(category_id: category_ids, visible: true)
      if since
        query = query.where('last_posted_at > ?', since)
        query = query.order(last_posted_at: :desc)
      else
        query = query.order(last_posted_at: :asc)
      end
      query
    end

    def index
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      sitemap_size = SiteSetting.sitemap_topics_per_page
      @output = Rails.cache.fetch("sitemap/index/v2/#{sitemap_size}", expires_in: 24.hours) do
        count = topics_query.count
        @size = count / sitemap_size
        @size += 1 if count % sitemap_size > 0

        # grabbing full sitemap more than once a day seems too much
        @lastmod = 1.day.ago
        1.upto(@size) do |i|
          Rails.cache.delete("sitemap/#{i}")
        end
        render :index, content_type: 'text/xml; charset=UTF-8'
      end
      render plain: @output, content_type: 'text/xml; charset=UTF-8' unless performed?
    end

    def default
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      page = Integer(params.require(:page))
      sitemap(page)
    end

    def recent
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      sitemap_size = SiteSetting.sitemap_topics_per_page

      @output = Rails.cache.fetch("sitemap/recent", expires_in: 5.minutes) do
        @topics = Array.new
        topics_query(3.days.ago).limit(sitemap_size).pluck(:id, :slug, :last_posted_at, :updated_at, :posts_count).each do |t|
          t[2] = t[3] if t[2].nil?
          @topics.push t
        end
        render :default, content_type: 'text/xml; charset=UTF-8'
      end
      render plain: @output, content_type: 'text/xml; charset=UTF-8' unless performed?
      return @output
    end

    def sitemap(page)
      sitemap_size = SiteSetting.sitemap_topics_per_page
      offset = (page - 1) * sitemap_size

      @output = Rails.cache.fetch("sitemap/#{page}/#{sitemap_size}", expires_in: 24.hours) do
        @topics = Array.new
        topics_query.limit(sitemap_size).offset(offset).pluck(:id, :slug, :last_posted_at, :updated_at).each do |t|
          t[2] = t[3] if t[2].nil?
          @topics.push t
        end
        render :default, content_type: 'text/xml; charset=UTF-8'
      end
      render plain: @output, content_type: 'text/xml; charset=UTF-8' unless performed?
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
      render plain: @output, content_type: 'text/xml; charset=UTF-8' unless performed?
    end
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSitemap::Engine, at: "/sitemap"
  end

  DiscourseSitemap::Engine.routes.draw do
    get ".xml" => "sitemap#index"
    get "news.xml" => "sitemap#news"
    get "recent.xml" => "sitemap#recent"
    get ":page.xml" => "sitemap#default"
  end

end
