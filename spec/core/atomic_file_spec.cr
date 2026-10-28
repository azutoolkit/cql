require "../spec_helper"
require "../../src/atomic_file"
require "file_utils"

describe CQL::AtomicFile do
  it "keeps the complete old file and removes the temporary file after a partial write fails" do
    directory = File.join(Dir.tempdir, "cql_atomic_#{Random::Secure.hex(8)}")
    Dir.mkdir_p(directory)
    path = File.join(directory, "schema.cr")
    File.write(path, "previous complete schema")
    expect_raises(IO::Error, "injected write failure") do
      CQL::AtomicFile.replace(path) do |file|
        file << "partial replacement"
        file.flush
        File.read(path).should eq "previous complete schema"
        raise IO::Error.new("injected write failure")
      end
    end
    File.read(path).should eq "previous complete schema"
    Dir.children(directory).should eq ["schema.cr"]
  ensure
    FileUtils.rm_rf(directory) if directory
  end

  it "replaces a completed file and preserves existing access permissions" do
    directory = File.join(Dir.tempdir, "cql_atomic_#{Random::Secure.hex(8)}")
    Dir.mkdir_p(directory)
    path = File.join(directory, "schema.cr")
    File.write(path, "old")
    File.chmod(path, 0o640)
    CQL::AtomicFile.replace(path) { |file| file << "complete replacement" }
    File.read(path).should eq "complete replacement"
    File.info(path).permissions.value.should eq 0o640
    Dir.children(directory).should eq ["schema.cr"]
  ensure
    FileUtils.rm_rf(directory) if directory
  end

  it "cleans up when the final rename fails" do
    directory = File.join(Dir.tempdir, "cql_atomic_#{Random::Secure.hex(8)}")
    path = File.join(directory, "schema.cr")
    Dir.mkdir_p(path)
    expect_raises(File::Error) { CQL::AtomicFile.replace(path) { |file| file << "replacement" } }
    Dir.exists?(path).should be_true
    Dir.children(directory).should eq ["schema.cr"]
  ensure
    FileUtils.rm_rf(directory) if directory
  end
end
