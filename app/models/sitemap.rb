# frozen_string_literal: true

class Sitemap < ::ActiveRecord::Base
  RECENT_SITEMAP_NAME ||= 'recent'

  def update_last_posted_at!
    query = self.name == RECENT_SITEMAP_NAME ? Sitemap.topics_query : Sitemap.topics_query_by_page(name.to_i)

    self.update!(
      last_posted_at: query.maximum(:updated_at) || 3.days.ago,
      enabled: true
    )
  end

  def self.update!
    count = topics_query.count
    size = count / Sitemap.size
    size += 1 if count % Sitemap.size > 0
    names = [RECENT_SITEMAP_NAME]

    size.times do |index|
      name = (index + 1).to_s
      self.find_or_initialize_by(name: name).update_last_posted_at!
      names << name
    end

    self.find_or_initialize_by(name: RECENT_SITEMAP_NAME).update_last_posted_at!
    self.where.not(name: names).update_all(enabled: false)
  end

  def self.topics_query(since = nil)
    category_ids = Category.where(read_restricted: false).pluck(:id)
    query = Topic.where(category_id: category_ids, visible: true)
    if since
      query = query.where('bumped_at > ?', since)
      query = query.order(bumped_at: :desc)
    else
      query = query.order(bumped_at: :asc)
    end
    query
  end

  def self.topics_query_by_page(index)
    offset = (index - 1) * Sitemap.size
    topics_query.limit(Sitemap.size).offset(offset)
  end

  def self.size
    SiteSetting.sitemap_topics_per_page
  end
end

# == Schema Information
#
# Table name: sitemaps
#
#  id             :bigint           not null, primary key
#  name           :string           not null
#  last_posted_at :datetime         not null
#  enabled        :boolean          default(TRUE), not null
#
# Indexes
#
#  index_sitemaps_on_name  (name) UNIQUE
#
