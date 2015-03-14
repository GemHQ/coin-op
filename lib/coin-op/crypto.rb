# Ruby bindings for libsodium, a port of DJB's NaCl crypto library
require "rbnacl/libsodium"
require "openssl"

module CoinOp
  module Crypto

    # A wrapper for NaCl's Secret Box, taking a user-supplied passphrase
    # and deriving a secret key, rather than using a (far more secure)
    # randomly generated secret key.
    #
    # NaCl Secret Box provides a high level interface for authenticated
    # symmetric encryption.  When creating the box, you must supply a key.
    # When using the box to encrypt, you must supply a random nonce.  Nonces
    # must never be re-used.
    #
    # Secret Box decryption requires the ciphertext and the nonce used to
    # create it.
    #
    # The PassphraseBox class takes a passphrase, rather than a randomly
    # generated key. It uses PBKDF2 to generate a key that, while not random,
    # is somewhat resistant to brute force attacks.  Great care should still
    # be taken to avoid passphrases that are subject to dictionary attacks.
    class PassphraseBox

      # Both class and instance methods need encoding help, so we supply
      # them to both scopes using extend and include, respectively.
      extend CoinOp::Encodings
      include CoinOp::Encodings

      # PBKDF2 work factor
      ITERATIONS = 100_000

      # Given passphrase and plaintext as strings, returns a Hash
      # containing the ciphertext and other values needed for later
      # decryption.  Binary values are encoded as hexadecimal strings.
      def self.encrypt(passphrase, plaintext)
        box = self.new(passphrase)
        box.encrypt(plaintext)
      end

      # PassphraseBox.decrypt "my great password",
      #   :salt => salt, :nonce => nonce, :ciphertext => ciphertext
      #
      def self.decrypt(passphrase, hash)
        salt, nonce, ciphertext =
          hash.values_at(:salt, :nonce, :ciphertext).map {|s| decode_hex(s) }
        box = self.new(passphrase, salt, hash[:iterations])
        box.decrypt(nonce, ciphertext)
      end

      attr_reader :salt

      # Initialize with an existing salt and iterations to allow
      # decryption.  Otherwise, creates new values for these, meaning
      # it creates an entirely new secret-box.
      def initialize(passphrase, salt=nil, iterations=nil)
        @salt = salt || RbNaCl::Random.random_bytes(16)
        @iterations = iterations || ITERATIONS

        key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(
          passphrase, @salt,
          # TODO: decide on a very safe work factor
          # https://www.owasp.org/index.php/Password_Storage_Cheat_Sheet
          #
          @iterations, # number of iterations
          32      # key length in bytes
        )
        @box = RbNaCl::SecretBox.new(key)
      end

      def encrypt(plaintext)
        nonce = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.nonce_bytes)
        ciphertext = @box.encrypt(nonce, plaintext)
        {
          :iterations => @iterations,
          :salt => hex(@salt),
          :nonce => hex(nonce),
          :ciphertext => hex(ciphertext)
        }
      end

      def decrypt(nonce, ciphertext)
        @box.decrypt(nonce, ciphertext)
      end

    end

  end
end
