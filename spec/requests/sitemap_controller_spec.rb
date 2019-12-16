# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseSitemap::SitemapController do
  describe '#default' do
    it 'does not fail then page is a string starting with a number' do
      get '/sitemap_1asd.xml'

      expect(response.status).to eq(404)
    end

    it 'does not fail when the page starts with a zero' do
      get '/sitemap_0.xml'

      expect(response.status).to eq(404)
    end

    it 'works' do
      get '/sitemap_1.xml'

      expect(response.status).to eq(200)
    end
  end
end
