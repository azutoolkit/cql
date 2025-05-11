# Helper module to track callback execution
module CallbackTracker
  class_property executions = [] of String

  def self.clear
    @@executions = [] of String
  end

  def self.add(callback_name)
    @@executions << callback_name
  end

  def self.included?(callback_name)
    @@executions.includes?(callback_name)
  end

  def self.order
    @@executions.dup
  end
end
