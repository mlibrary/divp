require 'thor'

module DIVP 
  class CLI < Thor
    desc 'test', 'test'
    def test
      puts 'test'
    end
  end
end
