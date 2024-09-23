module CQL
  # Represents a table in the database.
  # This class is responsible for handling table creation, modification, and deletion.
  #
  # ## Usage
  #
  # ```
  # table = Table.new(:users, schema)
  # => #<Table:0x00007f8e7a4e1e80>
  # ```
  #
  # ```
  # table.column(:id, Int64, primary: true)
  # table.column(:name, String)
  # table.create_sql
  # => "CREATE TABLE users (id BIGINT PRIMARY KEY, name TEXT);"
  # ```
  #
  # ```
  # table = Table.new(:users, schema)
  # table.drop!
  # => nil
  # ```
  #
  # ```
  # table = Table.new(:users, schema)
  # table.truncate!
  # => nil
  #
  # table = Table.new(:users, schema)
  # table.column(:id, Int64, primary: true)
  # table.column(:name, String)
  # table.create!
  # => nil
  # ```
  #
  class Table
    Log = ::Log.for(self)

    property table_name : Symbol
    getter columns : Hash(Symbol, BaseColumn) = {} of Symbol => BaseColumn
    getter primary : BaseColumn = PrimaryKey(Int64).new(:id, Int64)
    getter as_name : String?

    private getter schema : Schema

    def initialize(@table_name : Symbol, @schema : Schema, @as_name : String? = nil)
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** type [Any] the data type of the column
    # - **@param** auto_increment [Bool] whether the column should auto increment (default: true)
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: true)
    #
    # **Example** Adding a new primary key column
    #
    # ```
    # primary :id, Int64
    # primary :id, Int64, auto_increment: false
    # ```
    def primary(
      name : Symbol = :id,
      type : T.class = Int64,
      auto_increment : Bool = true,
      as as_name = nil,
      unique : Bool = true
    ) forall T
      primary = PrimaryKey(T).new(name, type, as_name, auto_increment, unique)
      primary.table = self
      @primary = primary
      @columns[name] = @primary
      @primary
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** type [T.class] the data type of the column
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** size [Int32, nil] the size of the column (default: nil)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # column :email, String
    # ```
    def column(
      name : Symbol,
      type : T.class,
      as as_name : String? = nil,
      null : Bool = false,
      default : DB::Any = nil,
      unique : Bool = false,
      size : Int32? = nil,
      index : Bool = false
    ) forall T
      col = Column(T).new(name, T, as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # integer :age
    # integer :age, as: "user_age", null: false, default: 18, unique: true, index: true
    # ```
    def integer(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Int32).new(name, Int32, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # bigint :age
    # bigint :age, as: "user_age", null: false, default: 18, unique: true, index: true
    # ```
    def bigint(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Int64).new(name, Int64, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # float :age
    # float :age, as: "user_age", null: false, default: 18.0, unique: true, index: true
    # ```
    def float(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Float32).new(name, Float32, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # double :age
    # double :age, as: "user_age", null: false, default: 18.0, unique: true, index: true
    # ```
    def double(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Float64).new(name, Float64, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # decimal :price
    # decimal :price, as: "product_price", null: false, default: 0.0, unique: true, index: true
    # ```
    def text(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32? = nil, index : Bool = false)
      col = Column(String).new(name, String, as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    def varchar(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32? = 1000, index : Bool = false)
      col = Column(String).new(name, String, as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # boolean :active
    # boolean :active, as: "is_active", null: false, default: false, unique: true, index: true
    # ```
    def boolean(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Bool).new(name, Bool, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # timestamp :created_at
    # timestamp :created_at, as: "created_at", null: false, default: Time.local, unique: true, index: true
    # ```
    def timestamp(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Time).new(name, Time, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # date :birthday
    # date :birthday, as: "date_of_birth", null: false, default: Time.local, unique: true, index: true
    # ```
    def date(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Date).new(name, Date, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    def json(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(JSON::Any).new(name, JSON::Any, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # interval :duration
    # interval :duration, as: "time_span", null: false, default: Time.local, unique: true, index: true
    # ```
    def interval(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Time::Span).new(name, Time::Span, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # blob :data
    # blob :data, as: "binary_data", null: false, default: nil, unique: true, index: true
    # ```
    def blob(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32? = nil, index : Bool = false)
      col = Column(Slice(UInt8)).new(name, Slice(UInt8), as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    #
    # **Example** Adding timestamps to the table
    #
    # ```
    # timestamps
    # ```
    def timestamps
      timestamp :created_at, default: "CURRENT_TIMESTAMP"
      timestamp :updated_at, default: "CURRENT_TIMESTAMP"
    end

    # Adds a new column to the table.
    # - **@param** columns [Array(Symbol)] the columns to be indexed
    # - **@param** unique [Bool] whether the index should be unique (default: false)
    # - **@param** table [Table] the table to add the index to (default: self)
    # - **@return** [Index] the new index
    #
    # **Example** Adding a new index
    #
    # ```
    # add_index([:email], unique: true)
    # add_index([:email, :username], unique: true)
    # add_index([:email, :username], unique: true, table: users)
    # ```
    def add_index(columns : Array(Symbol), unique : Bool = false, table : Table = self)
      Index.new(table, columns, unique)
    end

    # Generates the SQL to create the table.
    #
    # **Example**
    #
    # ```
    # table = Table.new(:users, schema)
    # table.column(:id, Int64, primary: true)
    # table.column(:name, String)
    # table.create_sql
    # ```
    #
    # ```
    # => "CREATE TABLE users (id BIGINT PRIMARY KEY, name TEXT);"
    # ```
    def create_sql
      Expression::CreateTable.new(self).accept(schema.gen).to_s
    end

    # Generates the SQL to drop the table.
    # - **@return** [String] the SQL query
    #
    # **Example**
    #
    # ```
    # table = Table.new(:users, schema)
    # table.drop_sql
    # ```
    #
    # ```
    # => "DROP TABLE users;"
    # ```
    def drop_sql
      Expression::DropTable.new(self).accept(schema.gen).to_s
    end

    # Generates the SQL to truncate the table.
    # - **@return** [String] the SQL query
    #
    # **Example**
    #
    # ```
    # table = Table.new(:users, schema)
    # table.truncate_sql
    # => "TRUNCATE TABLE users;"
    # ```
    def truncate_sql
      Expression::TruncateTable.new(self).accept(schema.gen).to_s
    end

    # Creates the table in the database.
    # - **@return** [Nil]
    #
    # **Example**
    #
    # ```
    # table = Table.new(:users, schema)
    # table.column(:id, Int64, primary: true)
    # table.column(:name, String)
    # table.create!
    # => nil
    # ```
    def create!
      schema.tables[table_name] = self if schema.tables[table_name].nil?
      Log.debug { "Creating table #{table_name}" }
      schema.exec "#{create_sql};"
    end

    # Drops the table from the database.
    # - **@return** [Nil]
    #
    # **Example**
    #
    # ```
    # table = Table.new(:users, schema)
    # table.drop!
    # => nil
    # ```
    def drop!
      Log.debug { "Dropping table #{table_name}" }
      schema.exec "#{drop_sql};"
    end

    # Truncates the table in the database.
    # - **@return** [Nil]
    #
    # **Example**
    # ```
    # table = Table.new(:users, schema)
    # table.truncate!
    # => nil
    # ```
    def truncate!
      Log.debug { "Truncating table #{table_name}" }
      schema.exec "#{truncate_sql};"
      schema.tables.delete[table_name]
    end

    # Gets table expression for Sql query generation
    # - **@return** [Expression::Table] the table expression
    #
    # **Example**
    #
    # ```
    # table = Table.new(:users, schema)
    # table.expression
    # => #<Expression::Table:0x00007f8e7a4e1e80>
    # ```
    def expression
      Expression::Table.new(self)
    end

    macro method_missing(call)
      def {{call.id}}
        columns[:{{call.id}}]
      end
    end
  end
end
