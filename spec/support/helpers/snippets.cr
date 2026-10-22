# Compiles or runs a Crystal snippet against this checkout, for specs that assert
# a compile-time error (or its absence). Run `crystal spec` from the repo root.
module Snippets
  def self.compile(source : String) : {Bool, String, String}
    run("build", ["--no-codegen"], source)
  end

  def self.run(source : String) : {Bool, String, String}
    run("run", [] of String, source)
  end

  private def self.run(command : String, flags : Array(String), source : String) : {Bool, String, String}
    path = File.join(Dir.current, ".tmp_cql_snippet_#{Random.rand(1_000_000)}.cr")
    output = IO::Memory.new
    error = IO::Memory.new

    File.write(path, source)
    status = Process.run("crystal", [command, path] + flags, output: output, error: error)
    {status.success?, output.to_s, error.to_s}
  ensure
    File.delete(path) if path && File.exists?(path)
  end
end
