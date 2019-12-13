# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseSitemap::SitemapController do
  describe '#default' do
    it 'does not fail then page is a string starting with a number' do
      get '/sitemap_1asd.xml'

      expect(response.status).to eq(404)
    end
  end
end
