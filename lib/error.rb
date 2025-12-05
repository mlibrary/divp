#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

# Processing error class
# For readability in error messages and elsewhere,
# wherever possible @path should be relative.
# In particular when an objid is included, @path should just be a filename.
class Error
  include Comparable

  attr_reader :description, :objid, :path

  def self.json_create(hash)
    new hash["data"]["description"],
      hash["data"]["barcode"] || hash["data"]["objid"],
      hash["data"]["path"]
  end

  def initialize(description, objid = nil, path = nil)
    raise "nil description passed to Error#initialize" if description.nil?

    @description = description
    @objid = objid
    @path = path
  end

  def <=>(other)
    return nil unless other.is_a?(self.class)

    [@objid || "", @path || "", @description] <=>
      [other.objid || "", other.path || "", other.description]
  end

  def to_s
    format "%<description>s%<objid>s%<path>s",
      description: @description,
      objid: (@objid.nil? ? "" : " #{@objid}"),
      path: (@path.nil? ? "" : " #{@path}")
  end

  def to_json(*args)
    {
      "json_class" => self.class.name,
      "data" => {description: @description, objid: @objid, path: @path}
    }.to_json(*args)
  end
end
