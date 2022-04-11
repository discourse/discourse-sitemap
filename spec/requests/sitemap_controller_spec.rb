# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DiscourseSitemap::SitemapController', if: defined?(DiscourseSitemap::SitemapController) do
  describe '#default' do
    before do
      Sitemap.create!(name: '1', last_posted_at: Time.now)
    end

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

    it 'generates correct page numbers' do
      topic = Fabricate(:topic)

      # 18 posts - one incomplete page

      (1..TopicView.chunk_size - 2).each { |idx| Fabricate(:post, topic: topic) }
      topic.update!(updated_at: 4.hour.ago)
      get '/sitemap_recent.xml'
      url = Nokogiri::XML::Document.parse(response.body).at_css('loc').text
      expect(url).not_to include('?page=2')

      # 19 posts - still one incomplete page

      Fabricate(:post, topic: topic)
      topic.update!(updated_at: 3.hour.ago)
      get '/sitemap_recent.xml'
      url = Nokogiri::XML::Document.parse(response.body).at_css('loc').text
      expect(url).not_to include('?page=2')

      # 20 posts - one complete page

      Fabricate(:post, topic: topic)
      topic.update!(updated_at: 2.hour.ago)
      get '/sitemap_recent.xml'
      url = Nokogiri::XML::Document.parse(response.body).at_css('loc').text
      expect(url).not_to include('?page=2')

      # 21 posts - two pages - one complete page and one incomplete page

      Fabricate(:post, topic: topic)
      topic.update!(updated_at: 1.hour.ago)
      get '/sitemap_recent.xml'
      url = Nokogiri::XML::Document.parse(response.body).at_css('loc').text
      expect(url).to include('?page=2')
    end
  end
end
