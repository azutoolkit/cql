# Counts the descriptors this process holds open on a file, for specs that check connections are closed.
module FileHandles
  def self.supported? : Bool
    Dir.exists?("/proc/self/fd")
  end

  def self.count(path : String) : Int32
    real_path = File.realpath(path)
    Dir.children("/proc/self/fd").count do |descriptor|
      (File.readlink("/proc/self/fd/#{descriptor}") rescue nil) == real_path
    end
  end
end
