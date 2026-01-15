#!/usr/bin/env ruby
# frozen_string_literal: true

# Based on https://gist.github.com/Integralist/9503099
module Symbolize
  def self.symbolize(obj)
    case obj
    when Hash
      return obj.each_with_object({}) do |(k, v), memo|
        memo.tap { |m| m[k.to_sym] = symbolize(v) }
      end
    when Array
      return obj.each_with_object([]) do |v, memo|
        memo << symbolize(v)
      end
    end
    obj
  end
end

# Hash#symbolize method
class Hash
  def symbolize
    Symbolize.symbolize self
  end
end

# Array#symbolize method
class Array
  def symbolize
    Symbolize.symbolize self
  end
end
