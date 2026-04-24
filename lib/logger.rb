class Logger
  include Enumerable

  attr_accessor :warnings, :errors
  def initialize(log: nil, objids: [],
    warnings: Warnings.new(objids: objids),
    errors: Errors.new(objids: objids))
    @log = log || []
    @warnings = warnings
    @errors = errors
  end

  def each(&block)
    @log.each do |line|
      block.call(line)
    end
  end

  def entries
    @log
  end

  def log(entry, time)
    info(entry, time)
  end

  def info(entry, time)
    entry += format(" (%.3f sec)", time) unless time.nil?
    @log << entry
  end

  def log_it(log_entry)
    add(log_entry)
  end

  def add(input)
    if input.is_a?(LogEntry)
      add_log_entry(input)
    else # it's an array
      input.each do |log_entry|
        add_log_entry(log_entry)
      end
    end
  end

  def warn(description, objid: nil, path: nil)
    warning = description.is_a?(Error) ? description : Error.new(description, objid, path)
    @warnings.add(warning)
  end

  def error(description, objid: nil, path: nil)
    error = description.is_a?(Error) ? description : Error.new(description, objid, path)
    @errors.add(error)
  end

  def to_json(state = nil, *)
    JSON::State.from_state(state).generate(@log)
  end

  private

  def add_log_entry(log_entry)
    case log_entry.level
    when :info
      info(log_entry.command, log_entry.time)
    when :warning
      warn(log_entry.error)
    when :error
      error(log_entry.error)
    end
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

  def each(&block)
    @list.each do |line|
      block.call(line)
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

class LogEntry
  def self.info(command:, time:)
    new(level: :info, command: command, time: time)
  end

  def self.warning(error:, objid: nil, path: nil)
    new(level: :warning, error: error, objid: objid, path: path)
  end

  def self.error(error:, objid: nil, path: nil)
    new(level: :error, error: error, objid: objid, path: path)
  end

  attr_reader :level, :command, :time, :error

  def initialize(level:, command: nil, time: nil, error: nil, objid: nil, path: nil)
    @level = level
    @command = command
    @time = time
    if error.is_a?(Error)
      @error = error
    elsif error.is_a?(String)
      @error = Error.new(error, objid, path)
    end
    @objid = objid
  end
end
