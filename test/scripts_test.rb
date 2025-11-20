#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"

class ScriptsTest < Minitest::Test
  SCRIPTS = %w[jhove process query shipments].freeze

  def test_scripts
    ScriptsTest::SCRIPTS.each do |script|
      cmd = "#{File.join(RSVP::APP_ROOT, "bin", script)} -h"
      _stdout_str, _stderr_str, code = Open3.capture3(cmd)
      assert code.success?, "#{cmd} runs without error"
    end
  end
end
