# Sitemap Plugin

* Authors: richard@discoursehosting.com (@RGJ) and michael@discoursehosting.com (@michaeld)
* Version: 1.0
* License: MIT License

## Installation

Follow [the usual installation instructions](https://meta.discourse.org/t/advanced-troubleshooting-with-docker/15927#Example:%20Install%20a%20plugin).

On a non-Docker install do `bundle exec rake plugin:install repo=http://github.com/discoursehosting/discourse-sitemap`. There is no need for asset precompilation.

## Setup 

Just go to Admin - Settings - Plugins and check `sitemap enabled`

## Usage 

The sitemap plugin publishes two files:

* `/sitemap.xml` : the regular Google Sitemap format
* `/sitemap/news.xml` : special sitemap for Google News containing all new topics in the last three days

## Known issues

The plugin does not use it's own engine, but monkey patched the `robots_txt` controller (since we had to do that anyway).
If you know how to fix [this issue](https://meta.discourse.org/t/help-wanted-on-plugin-controller/40258), any help is welcome.

## License

MIT

