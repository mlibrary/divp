#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "set" # standard:disable all

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

  def check_objid_lists
    s1 = Set.new shipment.metadata[:initial_barcodes]
    s2 = Set.new shipment.objids
    if (s1 - s2).any?
      logger.error("objids removed: #{(s1 - s2).to_a.join(", ")}")
    end
    return unless (s2 - s1).any?

    logger.error("objids added: #{(s2 - s1).to_a.join(", ")}")
  end

  def verify_source_checksums
    fixity = shipment.fixity_check do |image_file|
      @bar.next! image_file.objid_file
    end
    fixity[:added].each do |image_file|
      logger.error("SHA missing", objid: image_file.objid, path: image_file.file)
    end
    fixity[:removed].each do |image_file|
      logger.error("file missing", objid: image_file.objid, path: image_file.file)
    end
    fixity[:changed].each do |image_file|
      logger.error("SHA modified", objid: image_file.objid, path: image_file.file)
    end
  end

  def run_jhove(objid)
    jhove = JHOVE.new(shipment.objid_directory(objid), config)
    begin
      jhove.run
    rescue => e
      logger.error(e.message, objid: objid)
    end
    jhove.errors.each do |err|
      logger.error JHOVE.error_object(err)
    end
  end
end
