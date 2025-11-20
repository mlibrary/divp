#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "yaml"

require "symbolize"

# Handles parsing the config directory and the files in it.
# Config files live by default in the app-level config directory,
# i.e., rsvp/config.
# This can be augmented when necessary (for testing, mainly)
# by setting options[:config_dir] with the -d/--config-dir flag.
# The -c/--config_profile options are for specialized config files
# which are merged with the default files.
# If you pass the option "-c dlxs" then RSVP will try to load the following:
#   config/config.yml
#   config/config.local.yml (optional)
#   config/config.dlxs.yml
#   config/config.dlxs.local.yml (optional)
# in order, successively merging them. Meaning that values loaded later
# override earlier ones.
# There is no way to remove a config value using this mechanism, so care
# should be taken to design configurations that do not require the mere
# presence of a key to function correctly.
class Config
  def self.json_create(hash)
    new hash["data"]
  end

  def initialize(options = {})
    raise "non-Hash options passed to Config.new" unless options.is_a? Hash

    @options = options
    config.merge! Symbolize.symbolize(options)
  end

  def to_s
    config.to_s
  end

  def to_json(*args)
    {
      "json_class" => self.class.name,
      "data" => @config
    }.to_json(*args)
  end

  def config
    return @config unless @config.nil?

    @config = Symbolize.symbolize YAML.load_file config_path
    file = local_config_path
    if File.exist? file
      @config.merge! Symbolize.symbolize(YAML.load_file(file) || {})
    end
    @config.merge! profile_config if @options.key? :config_profile
    @config
  end

  # Delegate Hash methods to @config
  def respond_to_missing?(method, _include_all)
    config.respond_to?(method) || super
  end

  def method_missing(method, *args, &block)
    config.send(method, *args, &block)
  end

  private

  def profile_config
    return @profile_config unless @profile_config.nil?

    file = config_path @options[:config_profile]
    @profile_config = Symbolize.symbolize(YAML.load_file(file) || {})
    file = local_config_path @options[:config_profile]
    if File.exist? file
      @profile_config.merge! Symbolize.symbolize(YAML.load_file(file) || {})
    end
    @profile_config
  end

  def config_dir
    @config_dir ||= @options[:config_dir] ||
      File.expand_path("../config", __dir__)
  end

  def config_path(profile = nil)
    file = profile.nil? ? "config.yml" : "config.#{profile}.yml"
    path = File.join(config_dir, file)
    unless File.exist? path
      raise Errno::ENOENT, "can't locate config file #{path}"
    end

    path
  end

  def local_config_path(profile = nil)
    file = profile.nil? ? "config.local.yml" : "config.#{profile}.local.yml"
    File.join(config_dir, file)
  end
end
