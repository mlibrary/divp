class Log
  include Enumerable

  def initialize(log: nil, warnings: Warnings.new)
    @log = log || []
    @warnings = warnings
  end

  def each
    @log.each do |line|
      yield line
    end
  end

  def entries
    @log
  end

  def warnings
    @warnings.list
  end

  def log(entry, time)
    entry += format(" (%.3f sec)", time) unless time.nil?
    @log << entry
  end

  def log_it(data)
    case data.level
    when :info
      log(data.command, data.time)
    when :warning
      add_warning(data.error)
    end
  end

  def add_warning(warning)
    @warnings.add(warning)
  end

  def to_json(state = nil, *)
    JSON::State.from_state(state).generate(@log)
  end
end

class Exceptions
  include Enumerable

  attr_reader :list, :objids

  def initialize(bar: SilentProgressBar.new, objids: [], list: nil)
    @list = list || []
    @bar = bar
    @objids = objids
  end

  def each
    @list.each do |line|
      yield line
    end
  end

  def [](index)
    @list[index]
  end

  def []=(index, value)
    @list[index] = value
  end

  def to_json(state = nil, *)
    JSON::State.from_state(state).generate(@list)
  end

  def add(err)
    unless err.objid.nil? || objids.member?(err.objid)
      raise "unknown #{kind} objid #{err.objid}"
    end
    set_bar
    @list << err
  end

  def kind
    raise NotImplementedError
  end

  def set_bar
    raise NotImplementedError
  end
end

class Errors < Exceptions
  def kind
    :error
  end

  def set_bar
    @bar.error = true
  end
end

class Warnings < Exceptions
  def kind
    :warning
  end

  def set_bar
    @bar.warning = true
  end
end
