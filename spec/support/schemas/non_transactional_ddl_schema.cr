# SQLite underneath, but reports MySQL's dialect, so DDL is treated as non-transactional.
class NonTransactionalDdlSchema < CQL::Schema
  def dialect
    CQL::Adapter::MySql.dialect
  end
end
