#!/usr/bin/env python3
"""Seeded compilation corpus for typed predicates and actionable macro errors.

Run from the checkout. Successful cases execute SQL generation and parameter
assertions; negative cases must fail compilation with the expected CQL diagnostic.
This bounded corpus complements the CTE/window/JSON/geo specs, not exhaustive fuzzing.
"""
import argparse
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PRELUDE = '''require "./src/cql"
require "sqlite3"
FuzzDB = CQL::Schema.define(:fuzz, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:") do
  table :people do
    primary :id, Int64
    text :name
    integer :age
  end
end
class FuzzPerson
  include CQL::ActiveRecord::Model(Int64)
  db_context FuzzDB, :people
  property name : String = ""
  property age : Int32 = 0
end
'''


def check(source, expected=None):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".cr", prefix=".tmp_cql_fuzz_", dir=ROOT) as f:
        f.write(source)
        f.flush()
        command = [os.environ.get("CRYSTAL", "crystal"), "build" if expected else "run", f.name]
        if expected:
            command.append("--no-codegen")
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=180)
    if expected:
        assert result.returncode != 0 and expected in result.stderr, result.stderr
    else:
        assert result.returncode == 0, result.stderr


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=65)
    parser.add_argument("--cases", type=int, default=64)
    args = parser.parse_args()
    if not 1 <= args.cases <= 1000:
        parser.error("--cases must be between 1 and 1000")
    rng = random.Random(args.seed)
    source = PRELUDE
    for index in range(args.cases):
        value = rng.randint(-2**31, 2**31 - 1)
        text = "value_" + "".join(rng.choice("abc%_!'\\") for _ in range(20))
        method = rng.choice(["contains", "starts_with", "ends_with"])
        # JSON's quoted strings are valid Crystal here; no interpolation characters are generated.
        source += f'''q{index} = FuzzPerson.query.where {{ (age >= {value}) & name.{method}({json.dumps(text)}) }}
sql{index}, params{index} = q{index}.to_sql_with_params
raise "parameter lost in case {index}" unless params{index}.size == 2 && params{index}[0] == {value}
raise "literal interpolated in case {index}" if sql{index}.includes?({json.dumps(text)})
'''
    check(source)
    negatives = [
        ('belongs_to "owner", Missing, :owner_id', "association name must be a symbol literal"),
        ('belongs_to :owner, Missing, "owner_id"', "foreign_key must be a symbol literal"),
        ('has_many :items, Missing, dependent: :explode', "unsupported dependent option"),
        ('has_many "items", Missing', "association name must be a symbol literal"),
        ('has_one :item, Missing, dependent: :explode', "unsupported dependent option"),
    ]
    for declaration, diagnostic in negatives:
        check('require "./src/cql"\nclass Broken\ninclude CQL::ActiveRecord::Model(Int64)\n' + declaration + '\nend\n', diagnostic)
    print(f"seed={args.seed}: {args.cases} valid predicate expansions and {len(negatives)} negative macro cases passed")


if __name__ == "__main__":
    main()
