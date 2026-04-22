class Item
  PATH_COMPONENTS = 1
  OBJID_SEPARATOR = "/"

  def self.objid_to_path(objid)
    objid.split(self::OBJID_SEPARATOR)
  end

  def initialize(path)
    # path to deepest directory
    @path = path
  end

  def image_file_class
    ImageFile
  end

  # assumes something valid. Check validity before going in here.
  def objid
    objid_components.join(self.class::OBJID_SEPARATOR)
  end

  def objid_components
    starting_number = -1 * self.class::PATH_COMPONENTS
    @path.split(File::SEPARATOR)[starting_number..]
  end

  def image_files
    @image_files = (Dir.children(@path) || []).filter_map do |child|
      if valid_file_types.include?(ImageFile.file_type(child))
        file_path = File.join(@path, child)
        objid_file = File.join(objid_components, child)

        image_file_class.new(
          objid, file_path, objid_file, child
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
  PATH_COMPONENTS = 3
  OBJID_SEPARATOR = "."

  def image_file_class
    DLXSImageFile
  end
end
