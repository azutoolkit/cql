require "./errors"

module CQL::Postgres
  # A frontend/backend protocol version, and every rule that depends on it, so
  # the rest of the driver never compares version numbers itself.
  #
  # 3.0 is understood by every server since PostgreSQL 7.4. 3.2 (PostgreSQL 18)
  # enlarges the query-cancel secret key from 4 bytes to 4..256 bytes. 3.1 is
  # reserved and never used.
  struct ProtocolVersion
    include Comparable(ProtocolVersion)

    V3_0 = new(3, 0)
    V3_2 = new(3, 2)

    KNOWN    = {V3_0, V3_2}
    EARLIEST = V3_0
    LATEST   = V3_2

    getter major : Int32
    getter minor : Int32

    def initialize(@major : Int32, @minor : Int32)
    end

    # "3.0", "3.2" or "latest".
    def self.parse(text : String) : ProtocolVersion
      return LATEST if text == "latest"
      version = KNOWN.find { |known| known.to_s == text }
      version || raise ArgumentError.new("unsupported protocol version #{text.inspect} (use 3.0, 3.2 or latest)")
    end

    # The 32-bit number sent in the StartupMessage.
    def code : Int32
      (major << 16) | minor
    end

    # The version to use after the server named its newest one in
    # NegotiateProtocolVersion. The protocol says that field holds the newest
    # minor version, but servers before PostgreSQL 18 send the whole version
    # number (3.0 as 196608), so both forms are read.
    def negotiated(offered : Int32) : ProtocolVersion
      newest_minor = offered > 0xFFFF ? offered & 0xFFFF : offered
      ceiling = {major, Math.min(minor, newest_minor)}
      KNOWN.reverse_each.find { |known| {known.major, known.minor} <= ceiling } || EARLIEST
    end

    SECRET_KEY_SIZES_BEFORE_3_2 = 4..4
    SECRET_KEY_SIZES_FROM_3_2   = 4..256

    # The allowed length of the cancel secret key.
    def secret_key_sizes : Range(Int32, Int32)
      self >= V3_2 ? SECRET_KEY_SIZES_FROM_3_2 : SECRET_KEY_SIZES_BEFORE_3_2
    end

    def valid_secret_key?(key : Bytes) : Bool
      secret_key_sizes.includes?(key.size)
    end

    def <=>(other : ProtocolVersion) : Int32
      {major, minor} <=> {other.major, other.minor}
    end

    def to_s(io : IO) : Nil
      io << major << '.' << minor
    end
  end
end
