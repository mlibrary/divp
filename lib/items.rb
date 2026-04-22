class Items
  include Enumerable

  def initialize(path:, objid_config:)
    @path = path
    @objid_config = objid_config
  end

  def each
    items.each { |item| yield(item) }
  end

  def items
    @items ||= objids.map do |objid|
      Item.new(path: objid_directory(objid), objid_config: @objid_config)
    end
  end

  def objids
    dirs = Dir.children(@path).reject do |entry|
      ["source", "tmp"].include?(entry) ||
        !File.directory?(File.join(@path, entry))
    end
    dirs.map do |entry|
      find_objids_with_components(@path, [entry])
    end.flatten.uniq.sort
  end

  private

  def objid_directory(objid)
    File.join(@path, @objid_config.objid_to_path(objid))
  end

  def find_objids_with_components(dir, components)
    bars = []
    if components.count < @objid_config.path_components_count
      subdir = File.join(dir, components)
      subdirectories(subdir).each do |entry|
        more_bars = find_objids_with_components(dir, components + [entry])
        bars = (bars + more_bars).uniq
      end
    elsif components.count == @objid_config.path_components_count
      bars << @objid_config.path_components_to_objid(components)
    end
    bars
  end

  def subdirectories(dir)
    Dir.children(dir).reject do |entry|
      !File.directory?(File.join(dir, entry))
    end
  end
end
