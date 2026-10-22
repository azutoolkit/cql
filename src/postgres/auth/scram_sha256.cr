require "base64"
require "crypto/subtle"
require "digest/sha256"
require "openssl/hmac"
require "openssl/pkcs5"
require "random/secure"
require "../errors"

module CQL::Postgres::Auth
  # SCRAM-SHA-256 (RFC 5802 / RFC 7677) without channel binding. The user name
  # in the exchange is empty because the server takes it from the startup packet.
  # The password is NFKC-normalised, which is what SASLprep (RFC 4013) comes to
  # for the text people actually type; servers store the normalised form.
  class ScramSha256
    MECHANISM = "SCRAM-SHA-256"
    # PBKDF2 blocks the thread while it runs (about 0.4 s per million rounds);
    # servers default to 4096.
    MAX_ITERATIONS = 1_000_000

    @server_first = ""
    @auth_message = ""
    @server_signature : Bytes? = nil
    @verified = false
    @password : String

    def initialize(password : String, @nonce : String = Random::Secure.base64(18), @username : String = "")
      @password = password.unicode_normalize(Unicode::NormalizationForm::NFKC)
    end

    def inspect(io : IO) : Nil
      io << "#<" << self.class << '>'
    end

    private def client_first_bare : String
      "n=#{@username},r=#{@nonce}"
    end

    def initial_response : Bytes
      "n,,#{client_first_bare}".to_slice
    end

    # Answers the server-first message with the client proof.
    def continue(server_first : Bytes) : Bytes
      fail("the server-first message was already handled") if @server_signature
      @server_first = String.new(server_first)
      attributes = parse(@server_first)
      nonce = attributes['r']? || fail("server-first message has no nonce")
      fail("server nonce does not extend the client nonce") unless nonce.starts_with?(@nonce)
      salt = decode_base64(attributes['s']? || fail("server-first message has no salt"))
      iterations = attributes['i']?.try(&.to_i?) || fail("server-first message has no iteration count")
      fail("unreasonable iteration count") unless 0 < iterations <= MAX_ITERATIONS

      salted = OpenSSL::PKCS5.pbkdf2_hmac(@password, salt, iterations, OpenSSL::Algorithm::SHA256, 32)
      client_key = hmac(salted, "Client Key")
      client_final_without_proof = "c=biws,r=#{nonce}"
      @auth_message = "#{client_first_bare},#{@server_first},#{client_final_without_proof}"
      signature = hmac(Digest::SHA256.digest(client_key), @auth_message)
      @server_signature = hmac(hmac(salted, "Server Key"), @auth_message)
      proof = Bytes.new(32) { |index| client_key[index] ^ signature[index] }
      "#{client_final_without_proof},p=#{Base64.strict_encode(proof)}".to_slice
    end

    def verified? : Bool
      @verified
    end

    # Checks the server-final message proves the server knows the password too.
    def verify(server_final : Bytes) : Nil
      attributes = parse(String.new(server_final))
      fail("server rejected the exchange: #{attributes['e']}") if attributes.has_key?('e')
      expected = @server_signature || fail("the server-final message arrived before the exchange started")
      received = decode_base64(attributes['v']? || fail("server-final message has no signature"))
      fail("server signature does not match") unless received.size == expected.size && Crypto::Subtle.constant_time_compare(received, expected)
      @verified = true
    end

    private def parse(message : String) : Hash(Char, String)
      message.split(',').each_with_object({} of Char => String) do |part, attributes|
        attributes[part[0]] = part[2..] if part.size >= 2 && part[1] == '='
      end
    end

    private def decode_base64(text : String) : Bytes
      Base64.decode(text)
    rescue Base64::Error
      fail("malformed base64 from the server")
    end

    private def hmac(key : Bytes, data : String) : Bytes
      OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, key, data)
    end

    private def fail(reason : String) : NoReturn
      raise AuthenticationError.new("SCRAM-SHA-256: #{reason}")
    end
  end
end
