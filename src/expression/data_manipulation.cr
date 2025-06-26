require "./base_expression"

module Expression
  # Data manipulation operations - optimized for memory efficiency
  class Insert < Node
    getter table : Table
    getter columns : Set(BaseColumn)
    getter values : Array(Array(DB::Any))
    getter back : Array(BaseColumn)
    getter query : Query?

    def initialize(
      @table : Table,
      @columns : Set(BaseColumn) = Set(BaseColumn).new,
      @values : Array(Array(DB::Any)) = [] of Array(DB::Any),
      @back : Array(BaseColumn) = Array(BaseColumn).new,
      @query : Query? = nil,
    )
    end

    def initialize(
      table : Table,
      columns : Set(Column),
      values : Array(Array(DB::Any)) = [] of Array(DB::Any),
      back : Array(Column) = [] of Column,
      query : Query? = nil,
    )
      @table = table
      @columns = columns.map(&.as(BaseColumn)).to_set
      @values = values
      @back = back.map(&.as(BaseColumn))
      @query = query
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Update < Node
    getter table : Table
    getter setters : Array(Setter)
    getter where : Where?
    getter back : Set(BaseColumn)

    def initialize(
      @table : Table,
      @setters : Array(Setter) = [] of Setter,
      @where : Where? = nil,
      @back : Set(BaseColumn) = Set(BaseColumn).new,
    )
    end

    def initialize(
      table : Table,
      setters : Array(Setter) = [] of Setter,
      where : Where? = nil,
      back : Set(Column) = Set(Column).new,
    )
      @table = table
      @setters = setters
      @where = where
      @back = back.map(&.as(BaseColumn)).to_set
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Delete < Node
    getter table : Table
    getter where : Where?
    getter back : Set(BaseColumn)
    getter using : Table?

    def initialize(@table : Table, @where : Where? = nil, @back : Set(BaseColumn) = Set(BaseColumn).new, @using : Table? = nil)
    end

    def initialize(table : Table, where : Where? = nil, back : Set(Column) = Set(Column).new, using : Table? = nil)
      @table = table
      @where = where
      @back = back.map(&.as(BaseColumn)).to_set
      @using = using
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Setter < Node
    getter column : BaseColumn
    getter value : DB::Any

    def initialize(@column : BaseColumn, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
