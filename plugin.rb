# frozen_string_literal: true

# name: discourse-sitemap
# about: Generate XML sitemap for your Discourse forum.
# version: 1.2
# authors: DiscourseHosting.com, vinothkannans
# url: https://github.com/discourse/discourse-sitemap

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

  [
    '../app/models/sitemap.rb',
    '../app/jobs/scheduled/update_sitemaps.rb'
  ].each { |path| load File.expand_path(path, __FILE__) }

  class DiscourseSitemap::SitemapController < ::ApplicationController
    layout false
    skip_before_action :preload_json, :check_xhr
    before_action :check_sitemap_enabled

    def check_sitemap_enabled
      raise Discourse::NotFound unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/"
    end

    def index
      @sitemaps = Sitemap.where(enabled: true)

      render :index, content_type: 'text/xml; charset=UTF-8'
    end

    def default
      index = params.require(:page)
      sitemap = Sitemap.find_by(enabled: true, name: index.to_s)
      raise Discourse::NotFound if sitemap.blank?

      @output = Rails.cache.fetch("sitemap/#{index}/#{Sitemap.size}", expires_in: 24.hours) do
        @topics = Sitemap.topics_query_by_page(index.to_i).pluck(:id, :slug, :last_posted_at, :updated_at).to_a
        render :default, content_type: 'text/xml; charset=UTF-8'
      end
      render plain: @output, content_type: 'text/xml; charset=UTF-8' unless performed?
      @output
    end

    def recent
      sitemap = Sitemap.find_or_initialize_by(name: Sitemap::RECENT_SITEMAP_NAME)
      sitemap.update_last_posted_at!

      @output = Rails.cache.fetch("sitemap/recent/#{sitemap.last_posted_at.to_i}", expires_in: 1.hour) do
        @topics = Sitemap.topics_query(3.days.ago).limit(Sitemap.size).pluck(:id, :slug, :last_posted_at, :updated_at, :posts_count).to_a
        render :default, content_type: 'text/xml; charset=UTF-8'
      end
      render plain: @output, content_type: 'text/xml; charset=UTF-8' unless performed?
      @output
    end

    def news
      @output = Rails.cache.fetch("sitemap/news", expires_in: 5.minutes) do
        dlocale = SiteSetting.default_locale.downcase
        @locale = dlocale.gsub(/_.*/, '')
        @locale = dlocale.sub('_', '-') if @locale === "zh"
        @topics = Sitemap.topics_query(72.hours.ago).pluck(:id, :title, :slug, :created_at)
        render :news, content_type: 'text/xml; charset=UTF-8'
      end
      render plain: @output, content_type: 'text/xml; charset=UTF-8' unless performed?
    end
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSitemap::Engine, at: "/"
  end

  DiscourseSitemap::Engine.routes.draw do
    get "sitemap.xml" => "sitemap#index"
    get "news.xml" => "sitemap#news"
    get "sitemap_recent.xml" => "sitemap#recent"
    get "sitemap_:page.xml" => "sitemap#default", page: /[1-9][0-9]*/
  end

end
