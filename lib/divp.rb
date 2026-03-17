require_relative "../rsvp"
require "json"
require "optparse"
require "pathname"
require "yaml"

require "processor"
require "query_tool"
require "string_color"
require "thor"

module DIVP
  class CLI < Thor
    desc "process SHIPMENT_DIRECTORY", "process"
    option :config_profile, aliases: ["c"], desc: 'Configuration PROFILE (e.g., "dlxs" loads config.dlxs.yaml)'
    option :config_dir, aliases: ["d"], desc: "Configuration directory DIRECTORY"
    option :bitonal_resolution, aliases: ["br"], desc: "Valid bitonal image resolution (in ppi)", type: :numeric, default: 600
    option :contone_resolution, aliases: ["cr"], desc: "Valid contone image resolution (in ppi)", type: :numeric, default: 400
    option :help, aliases: ["h"], desc: 'Try "divp help process"'
    option :restart_all, aliases: ["R"], desc: "Discard status.json and restart all stages", type: :boolean
    option :verbose, aliases: ["v"], desc: "Run verbosely"
    option :tagger_scanner, banner: "SCANNER", desc: "Set scanner tag to SCANNER"
    option :tagger_software, banner: "SOFTWARE", desc: "Set scan software tag to SOFTWARE"
    option :tagger_artist, banner: "ARTIST", desc: "Set artist tag to ARTIST"

    def process(*shipment_directory)
      if shipment_directory.empty?
        raise Thor::RequiredArgumentMissingError, "Missing required parameter SHIPMENT_DIRECTORY".red
      end
      shipment_directory.each do |shipment_dir|
        dir = Pathname.new(shipment_dir).realpath.to_s
        unless File.exist?(dir) && File.directory?(dir)
          puts "Shipment directory #{dir.bold} does not exist, skipping".red
          next
        end
        begin
          processor = Processor.new(dir, options)
        rescue JSON::ParserError => e
          puts "unable to parse #{File.join(dir, status.json)}: #{e}"
          next
        rescue FinalizedShipmentError
          puts "Shipment has been finalized, image masters unavailable".red
          next
        end
        begin
          puts "Processing #{dir}...".blue
          processor.run
          processor.finalize
        rescue Interrupt
          puts "\nInterrupted".red
          next
        rescue FinalizedShipmentError
          puts "Shipment has been finalized, image masters unavailable".red
          next
        end
        processor.write_status_file
        tool = QueryTool.new processor
        tool.status_cmd
      end
    end

    def self.exit_on_failure?
      true
    end
  end
end
