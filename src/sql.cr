require "log"
require "./visitor"
require "./statements"
require "./select_builder"
require "./insert_builder"
require "./condition_builder"
require "./column_condition_builder"
require "./where_builder"
require "./generator"

module Sql
  VERSION = "0.1.0"

  def self.select(*columns)
    cols = columns.to_a.map { |col| Column.new(col) }
    SelectBuilder.new(cols)
  end

  def self.select(**tuple)
    cols = tuple.map { |k, v| Column.new(k.to_s, v) }
    SelectBuilder.new(cols)
  end

  def self.insert_into(table)
    InsertBuilder.new(table)
  end
end
