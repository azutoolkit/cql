require "./base_column"
require "./schema"

module CQL
  # Represents a table in the database: its columns, primary key, indexes and constraints,
  # and the DDL that creates, drops or truncates it.
  #
  # Tables are declared in a `Schema.define` block or with `Schema#table`, and read back by name.
  #
  # ## Usage
  #
  # ```
  # schema.table :tags do
  #   primary :id, Int64
  #   column :name, String
  # end
  #
  # tags = schema.tags
  # tags.create_sql # => "CREATE TABLE IF NOT EXISTS tags (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)"
  # tags.create!
  # tags.truncate!
  # tags.drop!
  # ```
  #
  class Table
    include QuotedNameCache

    Log = CQL.config.logger

    property table_name : Symbol

    getter columns : Hash(Symbol, BaseColumn) = {} of Symbol => BaseColumn
    # Bumped whenever `Schema#alter` changes the columns, so SQL rendered from them can be redone.
    getter columns_revision : Int32 = 0

    def columns_changed! : Nil
      @columns_revision += 1
    end

    # :nodoc:
    # Captures the name and columns that `Schema#alter` may change; the returned proc puts them back.
    def declaration_snapshot : ->
      name, columns = @table_name, @columns.dup
      -> { restore_declaration(name, columns) }
    end

    private def restore_declaration(name : Symbol, columns : Hash(Symbol, BaseColumn)) : Nil
      unless name == @table_name
        @schema.tables.delete(@table_name) if @schema.tables[@table_name]?.try(&.same?(self))
        @schema.tables[name] = self
        @table_name = name
      end
      @columns = columns
      columns_changed!
    end

    @primary : BaseColumn = PrimaryKey(Int32).new(:id)
    getter as_name : String?
    getter foreign_keys : Array(ForeignKey) = [] of ForeignKey
    getter unique_constraints : Array(UniqueConstraint) = [] of UniqueConstraint
    getter check_constraints : Array(CheckConstraint) = [] of CheckConstraint
    getter indexes : Array(Index) = [] of Index

    getter schema : Schema

    # Creates a new table instance. Applications declare tables with `Schema#table` instead.
    # - **@param** table_name [Symbol] The name of the table
    # - **@param** schema [Schema] The schema this table belongs to
    # - **@param** as_name [String, nil] An optional alias for the table
    # - **@raise** [Error] If the table name is invalid
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
    # schema.table :comments do
    #   primary :id, Int64
    #   column :post_id, Int64
    #   column :author_id, Int64
    #
    #   # References the primary key of `posts`
    #   foreign_key :post_id, references: :posts
    #
    #   # Explicit referenced column and ON DELETE CASCADE
    #   foreign_key [:author_id], references: :users, references_columns: [:id], on_delete: :cascade
    # end
    # ```
    #
    # Pass several columns in the array for a composite foreign key.
    def foreign_key(
      columns local_columns : Array(Symbol),
      references references_table : Symbol,
      references_columns : (Array(Symbol) | Symbol)? = nil,
      name : String? = nil,
      on_delete : Symbol = :no_action,
      on_update : Symbol = :no_action,
    )
      ref_columns = referenced_columns(references_table, references_columns)
      unless local_columns.size == ref_columns.size
        raise ArgumentError.new("Number of columns (#{local_columns.join(", ")}) must match number of referenced columns (#{ref_columns.join(", ")})")
      end

      fk = ForeignKey.new(
        table: self,
        columns: local_columns,
        references_table: references_table,
        references_columns: ref_columns,
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
      references_columns : (Array(Symbol) | Symbol)? = nil,
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

    # The columns a foreign key to *references_table* points at: *references_columns* when given,
    # otherwise that table's primary key.
    def referenced_columns(references_table : Symbol, references_columns : (Array(Symbol) | Symbol)?) : Array(Symbol)
      case references_columns
      in Array(Symbol) then references_columns
      in Symbol        then [references_columns]
      in Nil           then primary_key_columns(references_table)
      end
    end

    # Helper method to get primary key columns for a referenced table
    # Looks up the referenced table in the schema and returns its primary key column(s)
    # - **@param** table_name [Symbol] The name of the referenced table
    # - **@return** [Array(Symbol)] The primary key column names
    # - **@raise** [CQL::Error] If the referenced table is not found
    #
    # **Example**
    # ```
    # primary_key_columns(:users) # => [:id]
    # ```
    private def primary_key_columns(table_name : Symbol) : Array(Symbol)
      # Look up the referenced table in the schema
      referenced_table = @schema.tables[table_name]?

      unless referenced_table
        # If table not found in schema, default to [:id] for forward compatibility
        # This allows references to tables not yet defined in the schema
        Log.warn { "Referenced table '#{table_name}' not found in schema, assuming primary key is 'id'" }
        return [:id]
      end

      # Return the primary key column name(s)
      # Tables can have composite primary keys, but typically have a single primary key
      [referenced_table.primary_key.try(&.name) || :id]
    end

    # Adds a new primary key column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** type [T.class] the data type of the column (default: Int32)
    # - **@param** auto_increment [Bool] whether the column should auto increment (default: true)
    # - **@return** [PrimaryKey(T)] the new primary key column
    #
    # **Example** Adding a new primary key column
    #
    # ```
    # schema.table :tags do
    #   primary :id, Int64
    # end
    #
    # schema.table :countries do
    #   primary :id, Int32, auto_increment: false
    # end
    # ```
    def primary(
      name : Symbol,
      type : T.class = Int32,
      auto_increment : Bool = true,
    ) forall T
      primary = PrimaryKey(T).new(name: name, auto_increment: auto_increment)
      primary.table = self
      @primary = primary
      @columns[name] = @primary
      @primary
    end

    # The declared primary key, or nil. Unlike `primary`, reading it never changes the table.
    def primary_key : BaseColumn?
      @columns.each_value.find(&.is_a?(PrimaryKey))
    end

    # A bare `primary` in a table block declares the default `id` (Int32) key; once a key
    # is declared it returns that key. Query building uses `primary_key`, which never declares one.
    def primary : BaseColumn
      primary_key || primary(:id, Int32)
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** type [T.class] the data type of the column
    # - **@param** as [String, nil] an optional alias for the column
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :people do
    #   integer :age
    #   integer :score, as: "points", null: true, default: 0, index: true
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :pages do
    #   bigint :views
    #   bigint :external_id, null: true, unique: true, index: true
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :products do
    #   float :rating
    #   float :weight, null: true, default: 0.0
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :places do
    #   double :latitude
    #   double :longitude, null: true, default: 0.0
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :products do
    #   real :price
    #   real :discount, null: true, default: 0.0
    # end
    # ```
    def real(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = Column(Float64).new(name, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new `String` column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** size [Int32, nil] the declared length, `VARCHAR(size)` (default: nil)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :profiles do
    #   text :title
    #   text :bio, null: true, default: ""
    # end
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
    def varchar(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, size : Int32? = nil, index : Bool = false)
      col = Column(String).new(name, as_name, null, default, unique, size)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new column to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :accounts do
    #   boolean :active
    #   boolean :admin, default: false, index: true
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :events do
    #   timestamp :starts_at
    #   timestamp :cancelled_at, null: true, index: true
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :employees do
    #   date :birthday
    #   date :hired_on, null: true
    # end
    # ```
    def date(name : Symbol, as as_name : String? = nil, null : Bool = false, default : DB::Any = nil, unique : Bool = false, index : Bool = false)
      col = DateColumn(Date).new(name, as_name, null, default, unique)
      col.table = self
      @columns[name] = col
      col.index = index ? add_index(columns: [name], unique: unique) : nil
      col
    end

    # Adds a new JSON column (`JSON::Any`) to the table.
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :accounts do
    #   json :metadata
    #   json :settings, null: true
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :subscriptions do
    #   interval :duration
    #   interval :grace_period, null: true
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: false)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    # - **@return** [Column] the new column
    #
    # **Example** Adding a new column with default options
    #
    # ```
    # schema.table :attachments do
    #   blob :data
    #   blob :thumbnail, null: true
    # end
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
    # - **@param** as [String, nil] an optional alias for the column
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

    # Declares an index that `create!` and `Schema#build` create after the table.
    # Declaring an index with the same name again replaces the earlier one.
    # - **@param** columns [Array(Symbol)] the columns to be indexed
    # - **@param** unique [Bool] whether the index should be unique (default: false)
    # - **@param** name [String, nil] the index name (default: `idx_<table>_<columns>`)
    # - **@return** [Index] the new index
    #
    # **Example** Adding a new index
    #
    # ```
    # schema.table :accounts do
    #   column :email, String
    #   column :username, String
    #   add_index([:email], unique: true)
    #   add_index([:email, :username], unique: true, name: "idx_accounts_login")
    # end
    # ```
    def add_index(columns : Array(Symbol), unique : Bool = false, name : String? = nil) : Index
      index = Index.new(self, columns, unique, name)
      @indexes.reject! { |existing| existing.index_name == index.index_name }
      @indexes << index
      index
    end

    def index(columns : Array(Symbol), unique : Bool = false, name : String? = nil) : Index
      add_index(columns, unique, name)
    end

    # Adds a UNIQUE constraint to the table.
    # - **@param** columns [Array(Symbol)] The column(s) to include in the constraint.
    # - **@param** name [String, nil] Optional name for the constraint.
    # - **@return** [UniqueConstraint] The created unique constraint object.
    #
    # **Example**
    # ```
    # schema.table :people do
    #   column :first_name, String
    #   column :last_name, String
    #   column :email, String
    #   unique_constraint [:email]
    #   unique_constraint [:first_name, :last_name], name: "uk_person_name"
    # end
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
    # schema.table :products do
    #   column :price, Float64
    #   column :email, String
    #   check_constraint "price > 0"
    #   check_constraint "email LIKE '%@%'", name: "chk_email_format"
    # end
    # ```
    def check_constraint(condition : String, name : String? = nil)
      constraint = CheckConstraint.new(condition, name)
      @check_constraints << constraint
      constraint
    end

    # Generates the SQL to create the table.
    # Includes column definitions and foreign key constraints.
    def create_sql
      Expression::CreateTable.new(self).accept(schema.new_generator).to_s
    end

    # Generates one `CREATE INDEX` statement per declared index, skipped when the index already
    # exists (except on MySQL, which has no `IF NOT EXISTS` for indexes).
    def create_index_sqls(generator : Expression::Generator = schema.new_generator) : Array(String)
      indexes.map { |index| Expression::CreateIndex.new(index, if_not_exists: true).accept(generator) }
    end

    # The statements that create the table and its indexes, in execution order.
    def create_statements : Array(String)
      [create_sql].concat(create_index_sqls)
    end

    # Generates the SQL to drop the table.
    # - **@return** [String] the SQL query
    #
    # **Example**
    #
    # ```
    # schema.users.drop_sql # => "DROP TABLE IF EXISTS users"
    # ```
    def drop_sql
      Expression::DropTable.new(self).accept(schema.new_generator).to_s
    end

    # Generates the SQL to truncate the table (`DELETE FROM` on SQLite, which has no `TRUNCATE`).
    # - **@return** [String] the SQL query
    #
    # **Example**
    #
    # ```
    # schema.users.truncate_sql # => "DELETE FROM users"
    # ```
    def truncate_sql
      Expression::TruncateTable.new(self).accept(schema.new_generator).to_s
    end

    # Creates the table in the database. Goes through `Schema#ddl_transaction`.
    # - **@return** [Nil]
    #
    # **Example**
    #
    # ```
    # schema.users.create!
    # ```
    def create!
      schema.ddl_transaction do
        schema.tables[table_name] ||= self
        Log.debug { "Creating table #{table_name}" }
        create_statements.each { |sql| schema.exec sql }
      end
    end

    # Drops the table from the database. Goes through `Schema#ddl_transaction`.
    # - **@return** [Nil]
    #
    # **Example**
    #
    # ```
    # schema.users.drop!
    # ```
    def drop!
      Log.debug { "Dropping table #{table_name}" }
      schema.ddl_transaction { schema.exec "#{drop_sql};" }
    end

    # Truncates the table in the database. Goes through `Schema#ddl_transaction`.
    # - **@return** [Nil]
    #
    # **Example**
    # ```
    # schema.users.truncate!
    # ```
    def truncate!
      Log.debug { "Truncating table #{table_name}" }
      schema.ddl_transaction { schema.exec "#{truncate_sql};" }
    end

    # Gets table expression for Sql query generation
    # - **@return** [Expression::Table] the table expression
    #
    # **Example**
    #
    # ```
    # schema.users.expression
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
