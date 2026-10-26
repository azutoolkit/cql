require "file_utils"

# Stand-ins for the external tools CQL runs (pg_dump, mysqldump), so specs need none installed.
module FakeTools
  # Runs the block with *path* as PATH.
  def self.with_path(path : String, &)
    original = ENV["PATH"]?
    ENV["PATH"] = path
    yield
  ensure
    ENV["PATH"] = original
  end

  # Runs the block with *tool* first on PATH: a `sh` script running *script* with the tool's arguments.
  def self.with_tool(tool : String, script : String, &)
    dir = File.tempname("cql-fake-tools")
    Dir.mkdir(dir)
    File.write(File.join(dir, tool), "#!/bin/sh\n#{script}\n", perm: 0o755)
    # An empty PATH entry would mean the current directory, so an unset PATH adds none.
    with_path([dir, ENV["PATH"]?.presence].compact.join(':')) { yield }
  ensure
    FileUtils.rm_rf(dir) if dir
  end
end
