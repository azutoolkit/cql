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

    # array types
    BOOL_ARRAY        = 1000_u32
    INT2_ARRAY        = 1005_u32
    INT4_ARRAY        = 1007_u32
    TEXT_ARRAY        = 1009_u32
    BPCHAR_ARRAY      = 1014_u32
    VARCHAR_ARRAY     = 1015_u32
    INT8_ARRAY        = 1016_u32
    FLOAT4_ARRAY      = 1021_u32
    FLOAT8_ARRAY      = 1022_u32
    DATE_ARRAY        = 1182_u32
    TIMESTAMP_ARRAY   = 1115_u32
    TIMESTAMPTZ_ARRAY = 1185_u32
    NUMERIC_ARRAY     = 1231_u32
    UUID_ARRAY        = 2951_u32
    JSONB_ARRAY       = 3807_u32
  end
end
