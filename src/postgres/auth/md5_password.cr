require "digest/md5"

module CQL::Postgres::Auth
  # The legacy `md5` method: "md5" + md5(md5(password + user) + salt), in hex.
  module MD5Password
    def self.digest(user : String, password : String, salt : Bytes) : String
      inner = Digest::MD5.hexdigest("#{password}#{user}")
      outer = Digest::MD5.hexdigest(inner.to_slice + salt)
      "md5#{outer}"
    end
  end
end
