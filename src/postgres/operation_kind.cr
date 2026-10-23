module CQL::Postgres
  # Which kind of statement some SQL is, for telemetry: `insert`, `update`,
  # `delete` or `select`. A `WITH` query counts as the first data-modifying
  # statement it contains (`WITH moved AS (DELETE ...) INSERT ...` is a delete),
  # and quoted text and comments are not read (dollar-quoted strings and nested
  # block comments are, so they can mislabel a `WITH` query).
  module OperationKind
    ROW_LOCK = /\bfor\s+(?:no\s+key\s+)?(?:update|share)\b/i

    def self.of(sql : String) : Symbol
      text = without_quoted_text_and_comments(sql).lstrip
      case text[/\A\w+/]?.try(&.downcase)
      when "insert" then :insert
      when "update" then :update
      when "delete" then :delete
      when "with"   then modifying_in(text)
      else               :select
      end
    end

    private def self.modifying_in(text : String) : Symbol
      case text.gsub(ROW_LOCK, " ")[/\b(?:insert|update|delete)\b/i]?.try(&.downcase)
      when "insert" then :insert
      when "update" then :update
      when "delete" then :delete
      else               :select
      end
    end

    # One linear pass over the bytes (the delimiters are ASCII, which never
    # occurs inside a multi-byte character): a regex over a literal of a
    # million characters runs out of PCRE stack. An unterminated quote or
    # comment runs to the end.
    private def self.without_quoted_text_and_comments(sql : String) : String
      bytes = sql.to_slice
      kept = IO::Memory.new(bytes.size)
      index = 0
      while index < bytes.size
        byte = bytes[index]
        if byte == '\''.ord || byte == '"'.ord
          index = after_quoted(bytes, index)
          kept.write_byte(' '.ord.to_u8)
        elsif byte == '/'.ord && bytes[index + 1]? == '*'.ord
          index = after_block_comment(bytes, index)
          kept.write_byte(' '.ord.to_u8)
        elsif byte == '-'.ord && bytes[index + 1]? == '-'.ord
          index = line_end(bytes, index)
        else
          kept.write_byte(byte)
          index += 1
        end
      end
      String.new(kept.to_slice)
    end

    private def self.after_quoted(bytes : Bytes, start : Int32) : Int32
      quote = bytes[start]
      index = start + 1
      while index < bytes.size
        if bytes[index] == quote
          return index + 1 unless bytes[index + 1]? == quote
          index += 2 # a doubled quote is part of the text
        else
          index += 1
        end
      end
      bytes.size
    end

    private def self.after_block_comment(bytes : Bytes, start : Int32) : Int32
      index = start + 2
      while index < bytes.size
        return index + 2 if bytes[index] == '*'.ord && bytes[index + 1]? == '/'.ord
        index += 1
      end
      bytes.size
    end

    private def self.line_end(bytes : Bytes, start : Int32) : Int32
      index = start
      while index < bytes.size && bytes[index] != '\n'.ord
        index += 1
      end
      index
    end
  end
end
