require "./spec_helper"

SaveValidationDB = CQL::Schema.define(:save_validation_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("save_validation.db")) do
  table :counted_widgets do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

class CountingValidator < CQL::ActiveRecord::Validations::CustomValidator
  class_property runs = 0

  def initialize(@record : CountedWidget)
  end

  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    self.class.runs += 1
    [] of CQL::ActiveRecord::Validations::Error
  end
end

class CountedWidget
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: SaveValidationDB, table: :counted_widgets

  property name : String = ""

  use CountingValidator

  def initialize(@name = "")
  end
end

describe "saving runs validations once" do
  before_each do
    SaveValidationDB.counted_widgets.create!
    CountingValidator.runs = 0
  end

  after_each { SaveValidationDB.counted_widgets.drop! }

  it "validates a new record once when it is saved" do
    CountedWidget.new("new").save.should be_true

    CountingValidator.runs.should eq(1)
  end

  it "keeps validating a persisted record once when it is saved" do
    widget = CountedWidget.new("old")
    widget.save
    CountingValidator.runs = 0

    widget.name = "renamed"
    widget.save.should be_true

    CountingValidator.runs.should eq(1)
  end
end
