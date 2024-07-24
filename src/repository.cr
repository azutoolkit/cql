module Sql
  class Repository(T)
    def initialize(@schema : Schema, @table : Symbol)
    end

    def build(attrs : Hash(Symbol, DB::Any))
      T.new(attrs)
    end

    def query
      Query.new(@schema).from(@table)
    end

    def all
      query.all(T)
    end

    def find(id)
      query.where(id: id).first(T)
    rescue DB::NoResultsError
      nil
    end

    def find!(id)
      query.where(id: id).first!(T)
    end

    def find_by(**fields)
      query.where(**fields).first(T)
    end

    def find_all_by(**fields)
      query.where(**fields).all(T)
    end

    def insert
      Insert.new(@schema).into(@table)
    end

    def create(attrs : Hash(Symbol, DB::Any))
      insert.values(attrs).commit.last_insert_id
    end

    def create(**fields)
      insert.values(**fields).commit.last_insert_id
    end

    def update
      Update.new(@schema).update(@table)
    end

    def update(id, attrs : Hash(Symbol, DB::Any))
      update.set(**attrs).where(id: id).commit
    end

    def update(id, **fields)
      update.set(**fields).where(id: id).commit
    end

    def update_by(
      where_attrs : Hash(Symbol, DB::Any),
      update_attrs : Hash(Symbol, DB::Any)
    )
      update.set(**update_attrs).where(**where_attrs).commit
    end

    def update_all(attrs : Hash(Symbol, DB::Any))
      update.set(**attrs).commit
    end

    def delete
      Delete.new(@schema).from(@table)
    end

    def delete(id)
      delete.where(id: id).commit
    end

    def delete_by(**fields)
      delete.where(**fields).commit
    end

    def delete_all
      delete.commit
    end

    def count
      query.count.first!(Int64)
    end

    def exists?(**fields)
      query.where(**fields).limit(1).first(T) != nil
    rescue DB::NoResultsError
      false
    end

    def first
      query.order(id: :asc).limit(1).first(T)
    end

    def last
      query.order(id: :desc).limit(1).first(T)
    end

    def page(page_number, per_page = 10)
      offset = (page_number - 1) * per_page
      query.limit(per_page).offset(offset).all(T)
    end

    def per_page(per_page)
      query.limit(per_page).all(T)
    end
  end
end
