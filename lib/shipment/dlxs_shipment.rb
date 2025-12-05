#!/usr/bin/env ruby
# frozen_string_literal: true

# Shipment directory class for DLXS nested id/volume/number directories
class DLXSShipment < Shipment
  PATH_COMPONENTS = 3
  OBJID_SEPARATOR = "."
  def initialize(dir, metadata = nil)
    super
  end

  # Returns an error message or nil
  def validate_objid(objid)
    /^.*?\.\d\d\d\d\.\d\d\d$/.match?(objid) ? nil : "invalid volume/number"
  end
end
