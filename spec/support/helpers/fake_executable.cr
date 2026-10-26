require "file_utils"

# Controls which tools a spec finds on `PATH`, so code that shells out to one (`pg_dump`,
# `mysqldump`) runs without the real tool installed.
module FakeExecutable
  # Puts a shell script named *name* first on `PATH` for the duration of the block.
  def self.with(name : String, script : String, &)
    in_temp_dir do |dir|
      path = File.join(dir, name)
      File.write(path, "#!/bin/sh\n#{script}\n")
      File.chmod(path, 0o755)
      with_path([dir, ENV["PATH"]?].compact.join(Process::PATH_DELIMITER)) { yield }
    end
  end

  # Makes `PATH` an empty directory for the duration of the block, so no tool is found.
  def self.with_empty_path(&)
    in_temp_dir { |dir| with_path(dir) { yield } }
  end

  private def self.in_temp_dir(&)
    dir = File.join(Dir.tempdir, "cql_fake_executable_#{Process.pid}_#{Random::Secure.hex(4)}")
    Dir.mkdir_p(dir)
    yield dir
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  private def self.with_path(path : String, &)
    original = ENV["PATH"]?
    ENV["PATH"] = path
    yield
  ensure
    original ? (ENV["PATH"] = original) : ENV.delete("PATH")
  end
end
