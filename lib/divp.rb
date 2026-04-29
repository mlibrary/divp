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
    desc "process SHIPMENT_DIRECTORY", "Process shipment directories"
    option :config_profile, aliases: ["c"], desc: 'Configuration PROFILE (e.g., "dlxs" loads config.dlxs.yaml)'
    option :config_dir, aliases: ["d"], desc: "Configuration directory DIRECTORY"
    option :bitonal_resolution, aliases: ["--br"], desc: "Valid bitonal image resolution (in ppi)", type: :numeric, default: 600
    option :contone_resolution, aliases: ["--cr"], desc: "Valid contone image resolution (in ppi)", type: :numeric, default: 400
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

    desc "query [options] SHIPMENT_DIRECTORY", "Query Tool for examining a shipment"
    option :config_profile, aliases: ["c"], desc: 'Configuration PROFILE (e.g., "dlxs" loads config.dlxs.yaml)'
    option :config_dir, aliases: ["d"], desc: "Configuration directory DIRECTORY"
    option :verbose, aliases: ["v"], desc: "Run verbosely"
    def query(shipment_directory)
      dir = Pathname.new(shipment_directory).cleanpath.to_s
      unless File.exist?(dir) && File.directory?(dir)
        puts "Shipment directory #{dir.bold} does not exist".red
        exit 1
      end
      begin
        processor = Processor.new(dir, options)
      rescue JSON::ParserError => e
        puts "unable to parse #{File.join(dir, status.json)}: #{e}"
        exit 1
      end

      tool = QueryTool.new(processor)
      completions = QueryTool.commands + processor.shipment.objids
      Readline.completion_append_character = " "
      Readline.completion_proc = proc do |str|
        completions.grep(/^#{Regexp.escape(str)}/)
      end
      prompt = "> "
      begin
        while (line = Readline.readline(prompt, true).rstrip)
          cmd, *args = line.split
          begin
            case cmd
            when "agenda"
              tool.agenda_cmd
            when "objects", "barcodes", "ls"
              tool.objids_cmd
            when "errors"
              tool.errors_cmd(*args)
            when "help", "?"
              puts QueryTool.command_summary
            when "fixity"
              tool.fixity_cmd
            when "quit", "exit"
              break
            when "run"
              begin
                processor.run
                processor.query
              rescue Interrupt
                puts "\nInterrupted".red
              ensure
                processor.write_status
              end
            when "status"
              tool.status_cmd
            when "warnings"
              tool.warnings_cmd(*args)
            else
              next if cmd.nil?

              puts "Unknown command"
            end
          rescue => e
            puts "#{e.inspect.bold}\n  #{e.backtrace.join("\n  ")}".red
          end
        end
      rescue Interrupt
        puts "Goodbye".blue
        exit 0
      end
    end

    def self.exit_on_failure?
      true
    end
  end
end
