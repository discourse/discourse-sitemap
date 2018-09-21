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

      # 1 hour cache just in case new pages are added
      @output = Rails.cache.fetch("sitemap/index/v6/#{sitemap_size}", expires_in: 1.hour) do
        count = topics_query.count
        @size = count / sitemap_size
        @size += 1 if count % sitemap_size > 0

        # 3 days are covered by recent, no need to index so frequently
        @lastmod = 3.days.ago
        1.upto(@size) do |i|
          Rails.cache.delete("sitemap/#{i}")
        end
        render_to_string :index, content_type: 'text/xml; charset=UTF-8'
      end

      # fixes timestamp cause we need correct data for latest
      @output = @output.sub("[TIME_PLACEHOLDER]", last_posted_at.xmlschema)

      render plain: @output, content_type: 'text/xml; charset=UTF-8'
    end

    def default
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      if params[:page].to_i < 1
        raise ActionController::RoutingError.new('Not Found')
      end

      page = Integer(params.require(:page))
      sitemap(page)
    end

    def recent
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"

      sitemap_size = SiteSetting.sitemap_topics_per_page

      @output = Rails.cache.fetch("sitemap/recent/#{last_posted_at.to_i}", expires_in: 1.hour) do
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

    private

      def last_posted_at
        topics_query.where.not(last_posted_at: nil).last&.last_posted_at
      end
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSitemap::Engine, at: "/"
  end

  DiscourseSitemap::Engine.routes.draw do
    get "sitemap.xml" => "sitemap#index"
    get "news.xml" => "sitemap#news"
    get "sitemap_recent.xml" => "sitemap#recent"
    get "sitemap_:page.xml" => "sitemap#default"
  end

end
