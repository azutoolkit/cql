require "./base_column"
require "./schema"

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
    Log = CQL.config.logger

    property table_name : Symbol
    getter columns : Hash(Symbol, BaseColumn) = {} of Symbol => BaseColumn
    getter primary : BaseColumn = PrimaryKey(Int32).new(:id)
    getter as_name : String?
    getter foreign_keys : Array(ForeignKey) = [] of ForeignKey
    getter unique_constraints : Array(UniqueConstraint) = [] of UniqueConstraint
    getter check_constraints : Array(CheckConstraint) = [] of CheckConstraint

    getter schema : Schema

    # Creates a new table instance.
    # - **@param** table_name [Symbol] The name of the table
    # - **@param** schema [Schema] The schema this table belongs to
    # - **@param** as_name [String, nil] An optional alias for the table
    # - **@raise** [Error] If the table name is invalid
    #
    # **Example**
    # ```
    # table = Table.new(:users, schema)
    # table = Table.new(:users, schema, as: "user_table")
    # ```
    def initialize(@table_name : Symbol, @schema : Schema, @as_name : String? = nil)
      validate_table_name!
    end

    private def validate_table_name!
      if table_name.to_s.empty?
        raise Error.new("Table name cannot be empty")
      end
      if table_name.to_s.includes?(" ")
        raise Error.new("Table name cannot contain spaces")
      end
      if table_name.to_s[0].ascii_number?
        raise Error.new("Table name cannot start with a number")
      end
    end

    # Adds a foreign key constraint to the table.
    # - **@param** columns [Array(Symbol), Symbol] The column(s) in this table.
    # - **@param** references_table [Symbol] The table the foreign key references.
    # - **@param** references_columns [Array(Symbol), Symbol, nil] The column(s) in the referenced table. Defaults to the primary key of the referenced table if nil.
    # - **@param** name [String, nil] Optional name for the constraint.
    # - **@param** on_delete [Symbol] Action on delete (:cascade, :restrict, :set_null, :no_action). Default :no_action.
    # - **@param** on_update [Symbol] Action on update (:cascade, :restrict, :set_null, :no_action). Default :no_action.
    # - **@return** [ForeignKey] The created foreign key object.
    #
    # **Example**
    #
    # ```
    # # Simple foreign key referencing the primary key of 'users'
    # foreign_key :user_id, references: :users
    #
    # # Foreign key with explicit referenced column and ON DELETE CASCADE
    # foreign_key :author_id, references: :authors, references_columns: :id, on_delete: :cascade
    #
    # # Composite foreign key
    # foreign_key [:order_id, :product_id], references: :order_items, references_columns: [:o_id, :p_id]
    # ```
    def foreign_key(
      columns local_columns : Array(Symbol),
      references references_table : Symbol,
      references_columns : Array(Symbol) | Symbol | Nil = nil,
      name : String? = nil,
      on_delete : Symbol = :no_action,
      on_update : Symbol = :no_action,
    )
      ref_columns = case references_columns
                    when Array(Symbol) then references_columns
                    when Symbol        then [references_columns]
                    when Nil
                      # If nil, assume it references the primary key of the target table
                      # We might need to fetch the target table schema definition here,
                      # but for now, let's assume the primary key is always :id
                      # A more robust solution would look up the primary key name.
                      primary_key_columns(references_table) # Use helper to get PK
                    end

      # Validate column count match
      ref_cols_nn = ref_columns.not_nil!            # Assert it's not nil
      unless local_columns.size == ref_cols_nn.size # Use the non-nil variable
        raise ArgumentError.new("Number of columns (#{local_columns.join(", ")}) must match number of referenced columns (#{ref_cols_nn.join(", ")})")
      end

      fk = ForeignKey.new(
        table: self,
        columns: local_columns,
        references_table: references_table,
        references_columns: ref_cols_nn, # Use the non-nil variable here too
        name: name,
        on_delete: on_delete,
        on_update: on_update
      )
      @foreign_keys << fk
      fk
    end

    # Overload to accept a single column symbol
    def foreign_key(
      column local_column : Symbol,
      references references_table : Symbol,
      references_columns : Array(Symbol) | Symbol | Nil = nil,
      name : String? = nil,
      on_delete : Symbol = :no_action,
      on_update : Symbol = :no_action,
    )
      # Call the array version
      foreign_key(
        [local_column],
        references: references_table,
        references_columns: references_columns,
        name: name,
        on_delete: on_delete,
        on_update: on_update
      )
    end

    # Helper method to get primary key columns for a referenced table
    # NOTE: This currently assumes the schema is already loaded or accessible.
    # A more robust implementation might require passing the Schema object
    # or having a way to look up table definitions globally.
    private def primary_key_columns(table_name : Symbol) : Array(Symbol)
      # TODO: Implement actual lookup of the referenced table's primary key(s)
      # For now, default to [:id] as a placeholder.
      # This requires access to the Schema or other table definitions.
      # referenced_table = @schema.find_table(table_name) # Hypothetical
      # return referenced_table.primary_keys.map(&.name) if referenced_table
      [:id]
    end

    # Adds a new primary key column to the table.
    # - **@param** name [Symbol] the name of the column to be added (default: :id)
    # - **@param** type [T.class] the data type of the column (default: Int32)
    # - **@param** auto_increment [Bool] whether the column should auto increment (default: true)
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: true)
    # - **@return** [PrimaryKey(T)] the new primary key column
    #
    # **Example** Adding a new primary key column
    #
    # ```
    # primary :id, Int32
    # primary :id, Int32, auto_increment: false
    # ```
    def primary(
      name : Symbol = :id,
      type : T.class = Int32,
      auto_increment : Bool = true,
    ) forall T
      primary = PrimaryKey(T).new(name: name, auto_increment: auto_increment)
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
      index : Bool = false,
    ) forall T
      col = Column(T).new(name, as_name, null, default, unique, size)
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
      col = Column(Int32).new(name, as_name, null, default, unique)
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
      col = Column(Int64).new(name, as_name, null, default, unique)
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
      col = Column(Float32).new(name, as_name, null, default, unique)
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
      col = Column(Float64).new(name, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new REAL column to the table (SQLite floating point type).
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
    # real :price
    # real :price, as: "product_price", null: false, default: 0.0, unique: true, index: true
    # ```
    def real(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Float64).new(name, as_name, null, default, unique)
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
      col = Column(String).new(name, as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    def varchar(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32? = 1000, index : Bool = false)
      col = Column(String).new(name, as_name, null, default, unique, size)
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
      col = Column(Bool).new(name, as_name, null, default, unique)
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
      col = Column(Time).new(name, as_name, null, default, unique)
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
      col = Column(Date).new(name, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new JSON column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** type [T.class] the Crystal type to map the JSON to (default: JSON::Any)
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
    # # Defaults to JSON::Any
    # json :metadata
    #
    # # Using a custom type
    # class MySettings
    #   include JSON::Serializable
    #   property theme : String
    # end
    #
    # json :settings, MySettings
    #
    # json :metadata, JSON::Any, as: "meta", null: false, default: nil, unique: true, index: true
    # ```
    def json(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(JSON::Any).new(name, as_name, null, default, unique)
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
      col = Column(Time::Span).new(name, as_name, null, default, unique)
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
      col = Column(Slice(UInt8)).new(name, as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a lock_version column for optimistic locking.
    # Lock version is used to prevent race conditions when multiple users are updating the same record.
    # It is a counter that is incremented each time the record is updated.
    # If the record is updated by another user, the lock version will be different and the update will fail.
    # The user will then need to retry the operation.
    #
    # - **@param** name [Symbol] the name of the column to be added (default: :version)
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any] the default value for the column (default: 1)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new version column
    #
    # **Example** Adding a version column for optimistic locking
    #
    # ```
    # lock_version :version
    # ```
    def lock_version(name : Symbol = :version, as as_name : String? = nil, null : Bool = false, default : DB::Any = 1, index : Bool = false)
      col = Column(Int32).new(name, as_name, null, default, false, nil, nil, true)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name]) : nil
      col
    end

    # Returns all columns in the table that are marked as version columns
    # - **@return** [Array(Column)] an array of version columns
    def version_columns
      @columns.values.select(&.version_number?)
    end

    # Adds a new column to the table.
    # Interval is a column type that can be used to store a duration of time.
    # It is a wrapper around the Time::Span type.
    #
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new interval column
    #
    # ```
    # interval :duration
    # interval :duration, as: "time_span", null: false, default: Time.local, unique: true, index: true
    # ```
    def interval(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Time::Span).new(name, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # Blob is a column type that can be used to store binary data.
    # It is a wrapper around the Slice(UInt8) type.
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
      col = Column(Slice(UInt8)).new(name, as_name, null, default, unique, size)
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
      # Get the dialect-specific timestamp function string from the schema
      timestamp_default_value = @schema.dialect.current_timestamp
      timestamp(name: :created_at, default: timestamp_default_value)
      timestamp(name: :updated_at, default: timestamp_default_value)
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
    def add_index(columns : Array(Symbol), unique : Bool = false)
      index = Index.new(self, columns, unique, nil)
      index
    end

    def index(columns : Array(Symbol), unique : Bool = false)
      add_index(columns, unique)
    end

    # Adds a UNIQUE constraint to the table.
    # - **@param** columns [Array(Symbol)] The column(s) to include in the constraint.
    # - **@param** name [String, nil] Optional name for the constraint.
    # - **@return** [UniqueConstraint] The created unique constraint object.
    #
    # **Example**
    # ```
    # unique_constraint [:email]
    # unique_constraint [:first_name, :last_name], name: "uk_person_name"
    # ```
    def unique_constraint(columns : Array(Symbol), name : String? = nil)
      constraint = UniqueConstraint.new(columns, name)
      @unique_constraints << constraint
      constraint
    end

    # Adds a CHECK constraint to the table.
    # - **@param** condition [String] The SQL condition for the check constraint.
    # - **@param** name [String, nil] Optional name for the constraint.
    # - **@return** [CheckConstraint] The created check constraint object.
    #
    # **Example**
    # ```
    # check_constraint "price > 0"
    # check_constraint "email LIKE '%@%'", name: "chk_email_format"
    # ```
    def check_constraint(condition : String, name : String? = nil)
      constraint = CheckConstraint.new(condition, name)
      @check_constraints << constraint
      constraint
    end

    # Generates the SQL to create the table.
    # Includes column definitions and foreign key constraints.
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
      schema.tables.delete(table_name)
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
