module Sql
  class Repository(T)
    def initialize(@schema : Schema, @table : Symbol)
    end

    # Build a new object of type T with the given attributes
    def build(attrs : Hash(Symbol, DB::Any))
      T.new(attrs)
    end

    # Return a new query object for the current table
    def query
      Query.new(@schema).from(@table)
    end

    # Fetch all records of type T
    def all
      query.all(T)
    end

    # Find a record by ID, return nil if not found
    def find(id)
      query.where(id: id).first(T)
    rescue DB::NoResultsError
      nil
    end

    # Find a record by ID, raise an error if not found
    def find!(id)
      query.where(id: id).first!(T)
    end

    # Find a record by specific fields
    def find_by(**fields)
      query.where(**fields).first(T)
    end

    # Find all records matching specific fields
    def find_all_by(**fields)
      query.where(**fields).all(T)
    end

    # Return a new insert object for the current table
    def insert
      Insert.new(@schema).into(@table)
    end

    # Create a new record with given attributes
    def create(attrs : Hash(Symbol, DB::Any))
      insert.values(attrs).commit.last_insert_id
    end

    # Create a new record with given fields
    def create(**fields)
      insert.values(**fields).commit.last_insert_id
    end

    # Return a new update object for the current table
    def update
      Update.new(@schema).update(@table)
    end

    # Update a record by ID with given attributes
    def update(id, attrs : Hash(Symbol, DB::Any))
      update.set(**attrs).where(id: id).commit
    end

    # Update a record by ID with given fields
    def update(id, **fields)
      update.set(**fields).where(id: id).commit
    end

    # Update records matching where attributes with update attributes
    def update_by(
      where_attrs : Hash(Symbol, DB::Any),
      update_attrs : Hash(Symbol, DB::Any)
    )
      update.set(**update_attrs).where(**where_attrs).commit
    end

    # Update all records with given attributes
    def update_all(attrs : Hash(Symbol, DB::Any))
      update.set(**attrs).commit
    end

    # Return a new delete object for the current table
    def delete
      Delete.new(@schema).from(@table)
    end

    # Delete a record by ID
    def delete(id)
      delete.where(id: id).commit
    end

    # Delete records matching specific fields
    def delete_by(**fields)
      delete.where(**fields).commit
    end

    # Delete all records in the table
    def delete_all
      delete.commit
    end

    # Count all records in the table
    def count
      query.count.first!(Int64)
    end

    # Check if records exist matching specific fields
    def exists?(**fields)
      query.where(**fields).limit(1).first(T) != nil
    rescue DB::NoResultsError
      false
    end

    # Fetch the first record in the table
    def first
      query.order(id: :asc).limit(1).first(T)
    end

    # Fetch the last record in the table
    def last
      query.order(id: :desc).limit(1).first(T)
    end

    # Paginate results based on page number and items per page
    def page(page_number, per_page = 10)
      offset = (page_number - 1) * per_page
      query.limit(per_page).offset(offset).all(T)
    end

    # Limit the number of results per page
    def per_page(per_page)
      query.limit(per_page).all(T)
    end
  end
end
