module CQL
  # Validation for names that end up in SQL as identifiers (aliases, index and
  # constraint names). Values are always bound as parameters, but identifiers
  # cannot be, so anything user-controlled must be restricted to a safe shape.
  module Identifier
    PATTERN = /\A[A-Za-z_][A-Za-z0-9_]*\z/

    def self.valid?(name : String) : Bool
      PATTERN.matches?(name)
    end

    # Returns *name* unchanged when it is a plain identifier, otherwise raises.
    def self.validate!(name : String, kind : String = "identifier") : String
      return name if valid?(name)
      raise ArgumentError.new("Invalid #{kind} #{name.inspect}: only letters, digits and underscores are allowed, and it must not start with a digit")
    end
  end
end
