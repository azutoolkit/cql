require "file/tempfile"

module CQL
  # :nodoc:
  # A failed write or flush must leave the previous schema intact. Keep the
  # temporary file on the same filesystem so rename is an atomic replacement.
  module AtomicFile
    def self.replace(path : String, & : File ->) : Nil
      directory = File.dirname(path)
      Dir.mkdir_p(directory)
      temporary = File.tempfile(".cql-schema-", dir: directory)
      begin
        if info = File.info?(path, follow_symlinks: false)
          temporary.chmod(info.permissions) if info.file?
        end
        yield temporary
        temporary.flush
        temporary.fsync
        temporary.close
        File.rename(temporary.path, path)
      ensure
        temporary.close
        File.delete?(temporary.path)
      end
    end
  end
end
