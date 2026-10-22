require "../spec_helper"

describe "playground/cql_demo.cr" do
  it "runs end to end and prints every section" do
    output = IO::Memory.new
    status = Process.run("crystal", ["run", "playground/cql_demo.cr"], output: output, error: output)

    status.success?.should be_true, output.to_s
    (1..11).each { |section| output.to_s.should contain("== #{section}. ") }
    output.to_s.should contain("table still exists: 3 authors")
  end
end
