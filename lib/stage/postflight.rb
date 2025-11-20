#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "set"

require "jhove"
require "stage"

# Image Metadata Validation Stage
class Postflight < Stage
  def run(agenda)
    @bar.steps = steps agenda
    agenda.each do |objid|
      @bar.next! "validate #{objid}"
      run_jhove objid
    end
    @bar.next! "objid check"
    check_objid_lists
    @bar.next! "verify checksums"
    verify_source_checksums
  end

  private

  def steps(agenda)
    agenda.count + 2 +
      shipment.source_image_files.count +
      shipment.checksums.keys.count
  end

  def check_objid_lists # rubocop:disable Metrics/AbcSize
    s1 = Set.new shipment.metadata[:initial_barcodes]
    s2 = Set.new shipment.objids
    if (s1 - s2).any?
      add_error Error.new("objids removed: #{(s1 - s2).to_a.join(", ")}")
    end
    return unless (s2 - s1).any?

    add_error Error.new("objids added: #{(s2 - s1).to_a.join(", ")}")
  end

  def verify_source_checksums # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    fixity = shipment.fixity_check do |image_file|
      @bar.next! image_file.objid_file
    end
    fixity[:added].each do |image_file|
      add_error Error.new("SHA missing", image_file.objid, image_file.file)
    end
    fixity[:removed].each do |image_file|
      add_error Error.new("file missing", image_file.objid, image_file.file)
    end
    fixity[:changed].each do |image_file|
      add_error Error.new("SHA modified", image_file.objid, image_file.file)
    end
  end

  def run_jhove(objid)
    jhove = JHOVE.new(shipment.objid_directory(objid), config)
    begin
      jhove.run
    rescue => e
      add_error Error.new(e.message, objid)
    end
    jhove.errors.each do |err|
      add_error JHOVE.error_object(err)
    end
  end
end
