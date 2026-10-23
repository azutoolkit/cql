module CQL::Postgres::Types
  # Built-in type OIDs (pg_type.oid) the driver decodes.
  module OID
    BOOL        =   16_u32
    BYTEA       =   17_u32
    CHAR        =   18_u32
    NAME        =   19_u32
    INT8        =   20_u32
    INT2        =   21_u32
    INT4        =   23_u32
    TEXT        =   25_u32
    OID         =   26_u32
    JSON        =  114_u32
    FLOAT4      =  700_u32
    FLOAT8      =  701_u32
    BPCHAR      = 1042_u32
    VARCHAR     = 1043_u32
    DATE        = 1082_u32
    TIME        = 1083_u32
    TIMESTAMP   = 1114_u32
    TIMESTAMPTZ = 1184_u32
    NUMERIC     = 1700_u32
    UUID        = 2950_u32
    JSONB       = 3802_u32
  end
end
