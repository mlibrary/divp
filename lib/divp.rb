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
    desc 'process SHIPMENT_DIRECTORY', 'process'
    option :config_profile, :aliases => ['c'], :desc => 'Configuration PROFILE (e.g., "dlxs" loads config.dlxs.yaml)'
    option :config_dir, :aliases => ['d'], :desc => 'Configuration directory DIRECTORY'
    option :help, :aliases => ['h'], :desc => 'Try "divp help process"'
    option :restart_all, :aliases => ['R'], :desc => 'Discard status.json and restart all stages', :type => :boolean
    option :verbose, :aliases => ['v'], :desc => 'Run verbosely'
    option :tagger_scanner, :banner => 'SCANNER', :desc => 'Set scanner tag to SCANNER'
    option :tagger_software, :banner => 'SOFTWARE', :desc => 'Set scan software tag to SOFTWARE'
    option :tagger_artist, :banner => 'ARTIST', :desc => 'Set artist tag to ARTIST'

    def process(*shipment_directory)
      if shipment_directory.empty?
        raise Thor::RequiredArgumentMissingError, 'Missing required parameter SHIPMENT_DIRECTORY'.red
      end
      puts options
      puts shipment_directory
    end

    def self.exit_on_failure?
      true
    end
  end
end
