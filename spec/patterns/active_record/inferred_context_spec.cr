require "./spec_helper"

struct InferredGadget
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredCategory
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredDay
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredBox
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredAddress
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredBuzz
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredBranch
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredDish
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

module InferredShop
  struct ShopOrder
    include CQL::ActiveRecord::Model(Int64)

    property id : Int64?
    property name : String

    def initialize(@name : String); end
  end
end

describe "Model without db_context" do
  describe ".table" do
    it "pluralizes and underscores the type name" do
      InferredGadget.table.should eq(:inferred_gadgets)
    end

    it "turns a trailing consonant-y into ies" do
      InferredCategory.table.should eq(:inferred_categories)
    end

    it "keeps a trailing vowel-y and adds s" do
      InferredDay.table.should eq(:inferred_days)
    end

    it "adds es after an x ending" do
      InferredBox.table.should eq(:inferred_boxes)
    end

    it "adds es after an s ending" do
      InferredAddress.table.should eq(:inferred_addresses)
    end

    it "adds es after a z ending" do
      InferredBuzz.table.should eq(:inferred_buzzes)
    end

    it "adds es after a ch ending" do
      InferredBranch.table.should eq(:inferred_branches)
    end

    it "adds es after an sh ending" do
      InferredDish.table.should eq(:inferred_dishes)
    end

    it "uses only the last namespace segment" do
      InferredShop::ShopOrder.table.should eq(:shop_orders)
    end

    it "still honours an explicit db_context table" do
      TestUser.table.should eq(:users)
    end
  end
end
