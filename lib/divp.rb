require_relative '../rsvp'
require 'json'
require 'optparse'
require 'pathname'
require 'yaml'

require 'processor'
require 'query_tool'
require 'string_color'
require 'thor'

module DIVP 
  class CLI < Thor
    desc 'process', 'process'
    option :config_profile, :aliases => ['c'], :desc => 'Configuration PROFILE (e.g., "dlxs" loads config.dlxs.yaml; optional)', :default => nil
    option :config_dir, :aliases => ['d'], :desc => 'Configuration directory DIRECTORY (optional)', :default => nil
    option :restart_all, :aliases => ['R'], :desc => 'Discard status.json and restart all stages', :type => :boolean
    option :verbose, :aliases => ['v'], :desc => 'Run verbosely'
    option :tagger_scanner, :banner => 'SCANNER', :desc => 'Set scanner tag to SCANNER'
    option :tagger_software, :banner => 'SOFTWARE', :desc => 'Set scan software tag to SOFTWARE'
    option :tagger_artist, :banner => 'ARTIST', :desc => 'Set artist tag to ARTIST'
    def process
      puts options[:config_profile]
    end

    def self.exit_on_failure?
      true
    end
  end
end
