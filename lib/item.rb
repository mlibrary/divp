class Item
  def initialize(path:, objid_config:)
    # path to deepest directory
    @path = path
    @objid_config = objid_config
  end

  # assumes something valid. Check validity before going in here.
  def objid
    objid_components.join(@objid_config.separator)
  end

  def objid_components
    starting_number = -1 * @objid_config.path_components
    @path.split(File::SEPARATOR)[starting_number..]
  end

  def create_image_file(objid:, file_path:, objid_file:, file:)
    ImageFile.new(
      objid, file_path, objid_file, file, @objid_config
    )
  end

  def image_files
    @image_files = (Dir.children(@path) || []).filter_map do |child|
      if valid_file_types.include?(ImageFile.file_type(child))
        file_path = File.join(@path, child)
        objid_file = File.join(objid_components, child)

        create_image_file(
          objid: objid, file_path: file_path, objid_file: objid_file, file: child
        )
      end
    end
  end

  def image_files_by_type(type)
    image_files.select do |image_file|
      image_file.file_type == type
    end
  end

  def valid_file_types
    ["jp2", "tif"]
  end
end

class DLXSItem < Item
end
