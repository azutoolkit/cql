# Bulk Load with COPY and Send Binary Parameters

Load or export many rows with one `COPY`, and send array and many-parameter statements' values in binary.

## COPY in Text Format

```crystal
engine.with_connection do |connection|
  copied = connection.copy_in("COPY users (name, email) FROM STDIN") do |io|
    io << "Ada\tada@example.com\n" # << takes a String, write takes Bytes; sent in 64 KiB pieces
    io << "Grace\tgrace@example.com\n"
  end
  copied # => 2

  connection.copy_out("COPY users (name, email) TO STDOUT") { |chunk| STDOUT.write(chunk) } # returns the row count
end
# If the block raises, copy_in aborts the COPY (no rows are loaded) and copy_out drops the
# remaining chunks; then the exception is re-raised.
# connection.session.copy_in(sql, timeout: 30.seconds) { |io| ... } bounds the COPY in time.
```

## COPY in Binary Format

```crystal
alias OID = CQL::Postgres::Types::OID

engine.with_connection do |connection|
  types = [OID::TEXT, OID::TEXT, OID::INT4]

  connection.copy_in_binary("COPY users (name, email, age) FROM STDIN (FORMAT binary)", types) do |rows|
    rows.row("Linus", "linus@example.com", 54)
    rows.write_row(["Barbara", nil, 85]) # nil is NULL
  end

  # On the session: Connection#copy_out_binary does not compile in this version
  connection.session.copy_out_binary("COPY users (name, email, age) TO STDOUT (FORMAT binary)", types) do |row|
    row # => ["Ada", "ada@example.com", 0] first: one Array per row, decoded per column type
  end
end
```

The signature, header and trailer are written and read for you, and rows may be split across chunks. `Session#copy_in_binary` and `#copy_out_binary` also take `timeout:`.

```crystal
engine.with_connection do |connection|
  connection.copy_in_binary("COPY users (name, age) FROM STDIN (FORMAT binary)", [OID::TEXT, OID::INT4]) do |rows|
    rows.row("Edsger", "72") # raises ArgumentError: column 2 (type 23) cannot take a String in binary
  end
end
# No conversion between kinds: an Int goes into int2/int4/int8 only if it fits. The message names
# the column and the Crystal class, never the value.
# Without (FORMAT binary) the methods raise ArgumentError: copy_in_binary before any data is sent,
# copy_out_binary after the output was read.
# Column types without a decoder, arrays among them, arrive as raw Bytes.
# To stop copy_out_binary early, raise from the block: the block is captured, so break is not allowed.
# A damaged stream or missing trailer raises CQL::Postgres::ProtocolError and drops the connection.
```

## Binary Parameters

Bind parameters go out as text, and the server parses them, unless **`binary_params=true`** is in the URL:

```crystal
engine = CQL::Postgres::AsyncEngine.connect("postgres://app:secret@db.internal/app?binary_params=true")
# Accepts true/on/1 and false/off/0 (the default); anything else raises ArgumentError.

engine.with_connection do |connection|
  connection.query_all("SELECT unnest($1::int8[])", [1_i64, 2_i64, 3_i64], as: Int64) # => [1, 2, 3]
  connection.session.binary_params_sent                                               # => 1
end
```

A `Bool`, `Int`, `Float32`, `Float64`, `UUID`, `Time`, `DecimalText`, `JSON::Any`, or an `Array` of those, waits until the server has described the statement, then goes out in binary when the reported type has a binary form: int2/int4/int8 (if the value fits), float4 (from a `Float32`), float8, bool, uuid, date, timestamp(tz), numeric (from `DecimalText` or an integer), jsonb, and arrays of those and of text, varchar and bpchar. Everything else stays text. Values are still bound parameters.

### When It Helps

The README's [measured compatibility](https://github.com/azutoolkit/cql#measured-compatibility) run (PostgreSQL 16, loopback, one machine, one run) found one scalar within noise of text, while multi-parameter statements and arrays gained from 6% (a seven-column insert) to 5.5× (`timestamptz[500]`). Measure your workload with [`benchmarks/pg_binary_params_bench.cr`](https://github.com/azutoolkit/cql/blob/master/benchmarks/pg_binary_params_bench.cr) before turning it on.

### Caveats

{% hint style="warning" %}
A deferred parameter keeps a reference to its array or JSON value; mutate it only after the statement returns. An array element that cannot be bound raises when the statement is bound, after the describe round trip.
{% endhint %}

- CockroachDB reads float4 and numeric differently, so those stay text there; it has no multi-dimensional arrays, and it accepts binary `COPY FROM` but answers binary `COPY TO` with `0A000 unimplemented`.
- Behind a transaction-mode pooler without prepared-statement support, use `statement_cache_size=0`; see [poolers](tls-and-poolers.md#poolers).

## Troubleshooting

**`ArgumentError` naming a column**: the Crystal value does not match the column type; pass an `Int64` for `int8`, a `String` for `text`.

**`ArgumentError: the COPY runs in text format`**: add `(FORMAT binary)` to the statement.

**`ProtocolError` on binary `COPY`**: the stream was damaged or ended without its trailer; retry on a fresh connection.

## See Also

- [Use AsyncEngine and Its Connection Pool](async-engine.md)
- [Stream Large Results and Pipeline Statements](streaming-and-pipelining.md)
- [Optimizing Queries in CQL](../performance/optimize-queries.md)
- [Use CockroachDB](../configuration/cockroachdb.md)
