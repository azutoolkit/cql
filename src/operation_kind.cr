module CQL
  # Which kind of statement some raw SQL is, for telemetry: `insert`, `update`,
  # `delete`, `select`, `explain`, or `ddl` for any other statement (`CREATE`,
  # `ALTER`, `SET`, `PRAGMA`, ...). A script is labeled by its first statement. A `WITH` query counts as the first
  # data-modifying statement it contains (`WITH moved AS (DELETE ...) INSERT ...`
  # is a delete), and quoted text and comments are not read (dollar-quoted
  # strings and nested block comments are, so they can mislabel a `WITH` query;
  # E'...' strings are).
  module OperationKind
    ROW_LOCK = /\bfor\s+(?:no\s+key\s+)?(?:update|share)\b/i

    def self.of(sql : String) : Symbol
      case first_word(sql)
      when "insert", "replace", "upsert"            then :insert
      when "update"                                 then :update
      when "delete"                                 then :delete
      when "with"                                   then modifying_in(without_quoted_text_and_comments(sql))
      when "select", "values", "table", "show", nil then :select
      when "explain"                                then :explain
      else                                               :ddl
      end
    end

    # The statement's first word, found without copying the SQL.
    private def self.first_word(sql : String) : String?
      bytes = sql.to_slice
      index = 0
      while index < bytes.size
        byte = bytes[index]
        if byte.unsafe_chr.whitespace?
          index += 1
        elsif byte == '/'.ord && bytes[index + 1]? == '*'.ord
          index = after_block_comment(bytes, index)
        elsif byte == '-'.ord && bytes[index + 1]? == '-'.ord
          index = line_end(bytes, index)
        else
          finish = index
          while finish < bytes.size && word_byte?(bytes[finish])
            finish += 1
          end
          return finish > index ? String.new(bytes[index, finish - index]).downcase : nil
        end
      end
    end

    private def self.word_byte?(byte : UInt8) : Bool
      byte.unsafe_chr.ascii_alphanumeric? || byte == '_'.ord
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
          index = after_quoted(bytes, index, escapes: byte == '\''.ord && escape_string_prefix?(bytes, index))
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

    # E'...' strings treat a backslash as an escape.
    private def self.escape_string_prefix?(bytes : Bytes, quote_at : Int32) : Bool
      return false unless quote_at > 0 && bytes[quote_at - 1].in?('e'.ord, 'E'.ord)
      quote_at == 1 || !word_byte?(bytes[quote_at - 2])
    end

    private def self.after_quoted(bytes : Bytes, start : Int32, escapes : Bool) : Int32
      quote = bytes[start]
      index = start + 1
      while index < bytes.size
        if escapes && bytes[index] == '\\'.ord
          index += 2
        elsif bytes[index] == quote
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
