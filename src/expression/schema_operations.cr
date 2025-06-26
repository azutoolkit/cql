require "./base_expression"

module Expression
  # Schema operations - optimized implementations
  class CreateTable < Node
    getter table : CQL::Table

    def initialize(@table : CQL::Table)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class DropTable < Node
    getter table : CQL::Table

    def initialize(@table : CQL::Table)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class TruncateTable < Node
    getter table : CQL::Table

    def initialize(@table : CQL::Table)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class AlterTable < Node
    getter table : CQL::Table
    getter action : AlterAction

    def initialize(@table : CQL::Table, @action : AlterAction)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Schema alteration actions
  abstract class AlterAction
    abstract def accept(visitor : Visitor)
  end

  class AddColumn < AlterAction
    getter column : CQL::BaseColumn

    def initialize(@column : CQL::BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class DropColumn < AlterAction
    getter column_name : String

    def initialize(@column_name : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class RenameColumn < AlterAction
    getter column : CQL::BaseColumn
    getter new_name : String
    getter old_name : String
    getter table_name : String

    def initialize(@column : CQL::BaseColumn, @new_name : String)
      @old_name = @column.name.to_s
      @table_name = @column.table.not_nil!.table_name.to_s
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class ChangeColumn < AlterAction
    getter column : CQL::BaseColumn
    getter type : CQL::Any
    getter table_name : String

    def initialize(@column : CQL::BaseColumn, @type : CQL::Any)
      @table_name = @column.table.not_nil!.table_name.to_s
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class RenameTable < AlterAction
    getter table : CQL::Table
    getter new_name : String

    def initialize(@table : CQL::Table, @new_name : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class AddForeignKey < AlterAction
    getter fk : CQL::ForeignKey

    def initialize(@fk : CQL::ForeignKey)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class DropForeignKey < AlterAction
    getter fk : String
    getter table : String

    def initialize(@fk : String, @table : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  alias AddIndex = CreateIndex

  class CreateIndex < AlterAction
    getter index : CQL::Index

    def initialize(@index : CQL::Index)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class DropIndex < AlterAction
    getter index : CQL::Index

    def initialize(@index : CQL::Index)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
