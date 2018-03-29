require 'ostruct'

module Rails
  def self.env
    OpenStruct.new(:test? => true)
  end
end
