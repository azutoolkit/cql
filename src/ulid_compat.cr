# ULID-compatible ID generator using Time.utc
# This provides a simple ULID-like implementation that works with modern Crystal
module CQL
  module ULIDCompat
    ENCODING = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    TIME_LEN = 10
    RANDOM_LEN = 16

    # Generate a ULID-compatible string (26 characters)
    def self.generate : String
      encode_time(Time.utc, TIME_LEN) + encode_random(RANDOM_LEN)
    end

    private def self.encode_time(time : Time, len : Int32) : String
      # Convert to milliseconds since epoch
      ms = (time - Time::UNIX_EPOCH).total_milliseconds.to_i64

      result = String::Builder.new(len)
      len.times do
        result << ENCODING[(ms % 32).to_i]
        ms //= 32
      end

      result.to_s.reverse
    end

    private def self.encode_random(len : Int32) : String
      result = String::Builder.new(len)
      len.times do
        result << ENCODING[Random.rand(32)]
      end
      result.to_s
    end
  end
end
