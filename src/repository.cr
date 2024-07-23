module Sql
  class Repository(T)
    def initialize(@schema : Schema, @table : Symbol)
    end

    def all
      query = Query.new(@schema).from(@table)
      query.all(T)
    end

    def find(id)
      query = Query.new(@schema).from(@table).where(id: id)
      query.first(T)
    end

    def find_by(**fields)
      query = Query.new(@schema).from(@table).where(**fields)
      query.first(T)
    end

    def find_all_by(**fields)
      query = Query.new(@schema).from(@table).where(**fields)
      query.all(T)
    end

    def create(attrs : Hash(Symbol, DB::Any))
      insert = Insert.new(@schema).into(@table).values(attrs)
      insert.commit
    end

    def create(**fields)
      insert = Insert.new(@schema).into(@table).values(**fields)
      insert.commit
    end

    def update(id, attrs : Hash(Symbol, DB::Any))
      update = Update.new(@schema).update(@table).set(**attrs).where(id: id)
      update.commit
    end

    def update(id, **fields)
      update = Update.new(@schema).update(@table).set(**fields).where(id: id)
      update.commit
    end

    def update_by(where_attrs : Hash(Symbol, DB::Any), update_attrs : Hash(Symbol, DB::Any))
      update = Update.new(@schema).update(@table).set(**update_attrs).where(**where_attrs)
      update.commit
    end

    def update_all(attrs : Hash(Symbol, DB::Any))
      update = Update.new(@schema).update(@table).set(**attrs)
      update.commit
    end

    def delete(id)
      delete = Delete.new(@schema).from(@table).where(id: id)
      delete.commit
    end

    def delete_by(**fields)
      delete = Delete.new(@schema).from(@table).where(**fields)
      delete.commit
    end

    def delete_all
      delete = Delete.new(@schema).from(@table)
      delete.commit
    end

    def count
      query = Query.new(@schema).from(@table).count
      query.first!(Int64)
    end

    def exists?(**fields)
      query = Query.new(@schema).from(@table).where(**fields).limit(1)
      query.first(T) != nil
    end

    def first
      query = Query.new(@schema).from(@table).order(id: :asc).limit(1)
      query.first(T)
    end

    def last
      query = Query.new(@schema).from(@table).order(id: :desc).limit(1)
      query.first(T)
    end

    def page(page_number, per_page = 10)
      offset = (page_number - 1) * per_page
      query = Query.new(@schema).from(@table).limit(per_page).offset(offset)
      query.all(T)
    end

    def per_page(per_page)
      query = Query.new(@schema).from(@table).limit(per_page)
      query.all(T)
    end
  end
end
