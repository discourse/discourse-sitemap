# name: External Sitemap
# about: 
# version: 0.1
# authors: DiscourseHosting.com
# url: https://github.com/discoursehosting/discourse-sitemap

PLUGIN_NAME = "discourse-sitemap".freeze

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
      # this code is never called somehow
      Rails.logger.error "Crappy"
      render :text => "<p>404 - Sitemap not found.</p>", :status => 404
    end
  end

  DiscourseSitemap::Engine.routes.draw do
    get "sitemap.xml" => "sitemap#generate"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseSitemap::Engine, at: "/"
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
  end
end

