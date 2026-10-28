export PATH=/tmp/claude-0/-home-user/448c1c81-04f8-5b52-9464-8cafcf121072/scratchpad/crystal-dl/crystal-1.22.1-1/bin:$PATH
export DATABASE_URL=postgres://example:example@localhost:5432/example
# A container restart stops the services the live specs need; start them when down (idempotent).
pg_isready -q 2>/dev/null || pg_ctlcluster 16 main start >/dev/null 2>&1
redis-cli ping >/dev/null 2>&1 || (cd /tmp/claude-0/-home-user/448c1c81-04f8-5b52-9464-8cafcf121072/scratchpad && redis-server --daemonize yes --dir /tmp/claude-0/-home-user/448c1c81-04f8-5b52-9464-8cafcf121072/scratchpad >/dev/null 2>&1)
