#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"
require "tag_data"
require "tiff"

# TIFF Metadata update stage
# The only thing that is required here is that the artist tag for 'dcu'
# is applied to all files that don't have it.
class Tagger < Stage
  def run(agenda)
    return unless agenda.any?

    calculate_tags
    return if errors.count.positive?

    files = image_files.select { |file| agenda.include? file.objid }
    @bar.steps = files.count
    files.each_with_index do |image_file, i|
      @bar.step! i, image_file.objid_file
      tag image_file
    end
  end

  private

  def calculate_tags # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    artist = config[:tagger_artist] || "dcu"
    @artist_tag ||= if TagData::ARTIST[artist].nil?
      add_warning Error.new("using custom artist '#{artist}'")
      artist
    else
      TagData::ARTIST[artist]
    end
    scanner = config[:tagger_scanner]
    unless scanner.nil?
      if TagData::SCANNER[scanner].nil?
        unless /\|/.match? scanner
          add_error Error.new("user-defined scanner not in 'make|model' format")
          return
        end

        add_warning Error.new("using custom scanner '#{scanner}'")
        @make_tag, @model_tag = scanner.split("|")
      else
        @make_tag, @model_tag = TagData::SCANNER[scanner]
      end
    end
    software = config[:tagger_software]
    return if software.nil?

    if TagData::SOFTWARE[software].nil?
      add_warning Error.new("using custom software '#{software}'")
      @software_tag = software
    else
      @software_tag = TagData::SOFTWARE[software]
    end
  end

  def tag(image_file) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    tagged_name = image_file.path.split(File::SEPARATOR)[-1] + ".tagged"
    tagged_path = File.join(tempdir_for_file(image_file), tagged_name)
    tagged = ImageFile.new(image_file.objid, tagged_path,
      File.join(image_file.objid,
        image_file.path + ".tagged"),
      image_file.file)
    FileUtils.cp(image_file.path, tagged_path)
    copy_on_success(tagged_path, image_file.path, image_file.objid)
    tag_artist tagged
    tag_scanner tagged
    tag_software tagged
    run_tiffset(tagged, TIFF::TIFFTAG_ORIENTATION, "1")
  end

  def tag_artist(image_file)
    return if @artist_tag.nil?

    run_tiffset(image_file, TIFF::TIFFTAG_ARTIST, @artist_tag)
  end

  def tag_scanner(image_file)
    run_tiffset(image_file, TIFF::TIFFTAG_MAKE, @make_tag) unless @make_tag.nil?
    return if @model_tag.nil?

    run_tiffset(image_file, TIFF::TIFFTAG_MODEL, @model_tag)
  end

  def tag_software(image_file)
    return if @software_tag.nil?

    run_tiffset(image_file, TIFF::TIFFTAG_SOFTWARE, @software_tag)
  end

  def tempdir_for_file(image_file)
    @objid_to_tempdir = {} if @objid_to_tempdir.nil?
    if @objid_to_tempdir.key? image_file.objid
      return @objid_to_tempdir[image_file.objid]
    end

    @objid_to_tempdir[image_file.objid] = create_tempdir
  end

  def run_tiffset(image_file, tag, value) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    begin
      info = TIFF.new(image_file.path).set(tag, value)
    rescue => e
      add_error Error.new(e.message, image_file.objid, image_file.file)
      return
    end
    log info[:cmd], info[:time]
    info[:warnings].each do |err|
      add_warning Error.new(err, image_file.objid, image_file.file)
    end
    info[:errors].each do |err|
      add_error Error.new(err, image_file.objid, image_file.file)
    end
  end
end
