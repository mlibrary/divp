#!/usr/bin/env ruby
# frozen_string_literal: true

# Shipment directory class for DLXS nested id/volume/number directories
class DLXSShipment < Shipment
  OBJID_CONFIG = ObjidConfig.new(path_components_count: 3, separator: ".")

  def validate_objid(objid)
    /^.*?\.\d\d\d\d\.\d\d\d$/.match?(objid) ? nil : "invalid volume/number"
  end
end
