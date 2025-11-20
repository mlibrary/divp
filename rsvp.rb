#!/usr/bin/env ruby
# frozen_string_literal: true

require "tmpdir"

# Top-level module for making sure our classes are loaded
# and Bundler is happy.
module RSVP
  APP_ROOT = File.expand_path(__dir__)

  # Bring Bundler into the mix.
  # Work around its issue with read-only home directory by temporarily
  # setting HOME to a writable temp directory.
  save_home = ENV["HOME"]
  tmpdir = Dir.mktmpdir
  begin
    ENV["HOME"] = tmpdir
    ENV["BUNDLE_GEMFILE"] ||= File.join(RSVP::APP_ROOT, "Gemfile")
    require "bundler/setup"
  ensure
    ENV["HOME"] = save_home
    FileUtils.rm_rf tmpdir
  end

  def self.add_load_path(dir)
    $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)
  end

  add_load_path File.join(APP_ROOT, "lib")
  add_load_path File.join(APP_ROOT, "lib", "stage")
  add_load_path File.join(APP_ROOT, "lib", "shipment")
end
