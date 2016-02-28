# name: External Sitemap
# about: 
# version: 0.1
# authors: DiscourseHosting.com
# url: https://github.com/discoursehosting/discourse-sitemap

PLUGIN_NAME = "discourse-sitemap".freeze

register_asset "xsl/sitemap-news.xsl"

after_initialize do

  module ::DiscourseSitemap
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseSitemap
    end
  end

  require_dependency "application_controller"

  class DiscourseSitemap::SitemapController < ::ApplicationController
    def generate
      prepend_view_path "plugins/discourse-sitemapcrap/app/views/" 
      # this code is never called somehow
    end
  end

  DiscourseSitemap::Engine.routes.draw do
    get "sitemap.xml" => "sitemap#generate"
  end

  Discourse::Application.routes.prepend do
    get "newssitemap.xml" => "robots_txt#generatenewssitemap" 
    get "sitemap.xml" => "robots_txt#generatesitemap" 
#    mount ::DiscourseSitemap::Engine, at: "/"
  end

  RobotsTxtController.class_eval do

    def index
      prepend_view_path "plugins/discourse-sitemap/app/views/" 
      path = if SiteSetting.allow_index_in_robots_txt
        :index
      else
        :no_index
      end
      render path, content_type: 'text/plain'
    end

    def generatesitemap
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/" 

      @topics = Array.new
      Category.where(read_restricted: false).each do |c|
        topics = c.topics.visible
        topics.order(:created_at).reverse_order.each do |t|
          @topics.push t
        end
      end
      render :sitemap, content_type: 'text/xml; charset=UTF-8' 
    end

    def generatenewssitemap
      raise ActionController::RoutingError.new('Not Found') unless SiteSetting.sitemap_enabled
      prepend_view_path "plugins/discourse-sitemap/app/views/" 

      @topics = Array.new
      Category.where(read_restricted: false).each do |c|
        topics = c.topics.visible
        topics.created_since(72.hours.ago).order(:created_at).reverse_order.each do |t|
          @topics.push t
        end
      end
      render :newssitemap, content_type: 'text/xml; charset=UTF-8' 
    end
  end
end

