# Bulk Load with COPY and Send Binary Parameters

Use `COPY` to load or export many rows in one statement, and binary parameters to cut encoding cost for arrays and
statements with several parameters.

## COPY in Text Format

`Connection#copy_in` takes the `COPY ... FROM STDIN` statement and yields a `CQL::Postgres::CopyIn` you write to. It
returns the number of rows copied.

```crystal
engine.with_connection do |connection|
  copied = connection.copy_in("COPY events (id, name) FROM STDIN") do |io|
    io << "1\tsignup\n"
    io << "2\tlogin\n"
  end
  puts copied # => 2
end
```

`CopyIn#write(bytes)` sends raw chunks; `<<` sends a string. Data is flushed in 64 KiB pieces. If the block raises,
the COPY is aborted and the exception is re-raised.

`copy_out` streams `COPY ... TO STDOUT` chunks to the block:

```crystal
engine.with_connection do |connection|
  connection.copy_out("COPY events TO STDOUT") { |chunk| STDOUT.write(chunk) }
end
```

The same methods exist on `Session` and accept `timeout:`:

```crystal
connection.session.copy_in(sql, timeout: 30.seconds) { |io| ... }
```

## COPY in Binary Format

Binary `COPY` needs the statement written with `(FORMAT binary)` and the column type OIDs from
`CQL::Postgres::Types::OID`:

```crystal
OID = CQL::Postgres::Types::OID

engine.with_connection do |connection|
  types = [OID::INT8, OID::TEXT, OID::TIMESTAMPTZ]

  connection.copy_in_binary("COPY events (id, name, at) FROM STDIN (FORMAT binary)", types) do |rows|
    rows.row(1_i64, "signup", Time.utc)
    rows.row(2_i64, nil, Time.utc)
  end

  connection.copy_out_binary("COPY events (id, name, at) TO STDOUT (FORMAT binary)", types) do |row|
    puts row.inspect # one Array of decoded values per row
  end
end
```

The signature, header and trailer are handled for you, and rows may be split across chunks. A row held in an array can
go through `rows.write_row(values)`.

### Rules

- Each value needs a binary form for its column type. There is no conversion between kinds: an `Int` goes into
  int2/int4/int8 only if it fits, and a mismatch raises `ArgumentError` naming the column and the Crystal class only.
- A statement the server runs as text (no `(FORMAT binary)`) raises `ArgumentError` too, before data is sent for
  `copy_in_binary` and after the output has been read for `copy_out_binary`.
- Types without a decoder (arrays among them) come back as raw `Bytes`.
- To stop early, raise from the block; there is no `break`. Timeouts and `cancel` behave as in text `COPY`.
- A damaged stream or a missing trailer raises `CQL::Postgres::ProtocolError`, which drops the connection.

## Binary Parameters

Parameters are normally sent as text and the server infers their types. With `binary_params=true` in the URL, a
`Bool`, `Int`, `Float32`/`Float64`, `UUID`, `Time`, `DecimalText`, `JSON::Any` or an `Array` of those waits until the
statement has been described and is then sent in binary if the type the server reported has a binary form.

```crystal
engine = CQL::Postgres::AsyncEngine.connect("postgres://app:secret@db.internal/app?binary_params=true")
```

`binary_params` accepts `true`, `on`, `1`, `false`, `off` and `0`; anything else raises `ArgumentError`. It is **off by
default**.

What goes out in binary: int2/int4/int8 (the value must fit, otherwise the text form goes and the server reports the
range error), float4 (from a `Float32`) and float8, bool, uuid, timestamp, timestamptz, date, numeric (from
`DecimalText` or an integer), jsonb, and one- or multi-dimensional arrays of those and of text/varchar/bpchar. Strings,
`json`, `bytea` and anything else stay as they are. Values are still bound parameters.

Check what happened with `Session#binary_params_sent`:

```crystal
engine.with_connection { |c| puts c.session.binary_params_sent }
```

### When It Helps

The README's measurement on PostgreSQL 16 over loopback (one machine, one run) found a single value to be within the
noise of text, while arrays and statements with several parameters gained between 6% and 440% (`timestamptz[500]` was
5.4 times faster). Measure on your own workload with `benchmarks/pg_binary_params_bench.cr` before switching it on.

### Caveats

- A deferred parameter keeps a reference to the array or JSON value it was made from. Mutate it only after the
  statement has returned.
- Because the choice waits for the server's types, an array holding a value that cannot be bound raises when the
  statement is bound, after the describe round trip, not when the parameter is created.
- CockroachDB reads float4 and numeric differently, so those stay text there, and it has no multi-dimensional arrays.
  CockroachDB accepts binary `COPY FROM` but answers binary `COPY TO` with `0A000 unimplemented`.
- Behind PgBouncer in transaction mode without `max_prepared_statements`, use `statement_cache_size=0`; see
  [poolers](tls-and-poolers.md#poolers).

## Troubleshooting

**`ArgumentError` naming a column**: the Crystal value does not match the column's type. Pass an `Int64` for `int8`, a
`String` for `text`, and so on.

**`ArgumentError` about text `COPY`**: add `(FORMAT binary)` to the statement.

**`ProtocolError` on binary `COPY`**: the stream was damaged or ended without its trailer; the connection is dropped.
Retry on a fresh one.
