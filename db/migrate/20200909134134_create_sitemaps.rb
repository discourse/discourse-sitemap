# frozen_string_literal: true

class CreateSitemaps < ActiveRecord::Migration[6.0]
  def change
    create_table :sitemaps do |t|
      t.string :name, null: false
      t.datetime :last_posted_at, null: false
      t.boolean :enabled, null: false, default: true
    end

    add_index :sitemaps, :name, unique: true
  end
end
