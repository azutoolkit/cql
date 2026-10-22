require "../../spec_helper"

describe "has_one declarations" do
  it "compiles with a symbol, a string or the default foreign key, and registers the association" do
    success, _, error = Snippets.compile <<-CRYSTAL
      require "./src/cql"
      require "sqlite3"

      DB_ = CQL::Schema.define(:has_one_snippet, adapter: CQL::Adapter::SQLite, uri: "sqlite3://%3Amemory%3A") do
        table :owners do
          primary :id, Int64
        end
        table :cards do
          primary :id, Int64
          column :owner_id, Int64
          column :holder_id, Int64
          column :snippet_owner_id, Int64
        end
      end

      class SnippetOwner
        include CQL::ActiveRecord::Model(Int64)
        db_context DB_, :owners

        has_one :card, Card, foreign_key: :owner_id
        has_one :holder_card, Card, foreign_key: "holder_id"
        has_one :default_card, Card
      end

      class Card
        include CQL::ActiveRecord::Model(Int64)
        db_context DB_, :cards

        property owner_id : Int64
        property holder_id : Int64
        property snippet_owner_id : Int64
        def initialize(@owner_id, @holder_id, @snippet_owner_id); end
      end

      {% for name in %w[SnippetOwner__has_one__card SnippetOwner__has_one__holder_card SnippetOwner__has_one__default_card] %}
        {% unless CQL::ActiveRecord::AssociationRegistry.has_constant?(name.id.stringify) %}
          {% raise "has_one association was not registered: " + name %}
        {% end %}
      {% end %}
      CRYSTAL

    error.should eq("") if success
    success.should be_true
  end
end
