require "./result_set"

module CQL::Postgres
  # The rows one pipelined statement returned, readable like a query's:
  #
  # ```
  # engine = CQL::Postgres::AsyncEngine.connect(ENV["DATABASE_URL"])
  # results = engine.pipeline([User.query.where(active: true), Post.query])
  # results[0].as(CQL::Postgres::PipelineResult).all(as: User)
  # ```
  class PipelineResult
    getter result : Result

    def initialize(@result : Result, @statement : ::DB::Statement)
    end

    def rows_affected : Int64
      @result.rows_affected
    end

    # Every row mapped to *kind* (a class, `DB::Serializable` model included).
    def all(as kind : T.class) : Array(T) forall T
      read_rows(&.read(kind))
    end

    # Every row as a tuple of the given types: `all(as: {Int32, String})`.
    def all(as kinds : Tuple) : Array
      read_rows(&.read(*kinds))
    end

    def get(as kind : T.class) : T? forall T
      all(kind).first?
    end

    def get!(as kind : T.class) : T forall T
      get(kind) || raise ::DB::NoResultsError.new("the pipelined statement returned no rows")
    end

    private def read_rows(& : ResultSet -> T) : Array(T) forall T
      rows = ResultSet.new(@statement, @result, true)
      Array(T).new(@result.rows.size).tap do |mapped|
        rows.each { mapped << yield rows }
      end
    ensure
      rows.try(&.close)
    end
  end
end
