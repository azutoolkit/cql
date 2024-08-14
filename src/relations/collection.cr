
module Cql::Relation
  class Collection(T)
    def initialize(@schema : Schema, @table : Symbol, @fk_key : Symbol, @fk_value : Int64)
      @query = Query.new(@schema).from(@table).where(@fk_key => @fk_value)
      @insert = Insert.new(@schema).into(@table)
      @update = Update.new(@schema).table(@table).where(@fk_key => @fk_value)
      @delete = Delete.new(@schema).from(@table).where(@fk_key => @fk_value)
      @records = reload
    end

    def <<(record : T)
      record_id = @insert.values(record).last_insert_id
      @records << find(id: record_id)
    end

    def create(**attributes)
      attr = attributes.merge(@fk_key => @fk_value)
      record_id = @insert.values(attributes).last_insert_id
      @records << find(id: record_id)
    end

    def create!(**attributes)
      record_id = @insert
        .values(attributes.merge(@fk_key => @fk_value))
        .last_insert_id
      find(id: record_id)
    end

    def ids
      @records.map(&.id)
    end

    def ids=(ids : Array(Int64))
      clear
      @records = where(id: ids).all(T)
    end

    def delete(record : T)
      @delete.commit.rows_affected > 0
    end

    def =(other : Array(T))
      clear
      @records = other
    end

    def clear
      @update.set(@fk_key => nil).where(@fk_key => @fk_value).commit
      @records = [] of T
    end

    def empty?
      @records.empty?
    end

    def size
      @records.size
    end

    def find(**attributes)
      @query.where(attributes).first(T)
    end

    def where(**attributes)
      @query.where(**attributes).all(T)
    end

    def exists?(**attributes)
      @query.where(**attributes).all
    end

    def all
      @records
    end

    def reload
      @records = all
    end
  end
end
