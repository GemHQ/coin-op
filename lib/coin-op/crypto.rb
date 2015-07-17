# Ruby bindings for libsodium, a port of DJB's NaCl crypto library
require 'rbnacl'
require 'openssl'


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
      ITERATIONS = 90_000
      ITERATIONS_WINDOW = 20_000

      SALT_RANDOM_BYTES = 16
      KEY_SIZE = 32
      AES_CIPHER = 'AES-256-CBC'

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
        salt, iv, nonce, ciphertext =
          hash.values_at(:salt, :iv, :nonce, :ciphertext).map {|s| decode_hex(s) }

        mode = nil
        if iv.empty?
          mode = :nacl
        elsif nonce.empty?
          mode = :aes
        end
        
        box = self.new(passphrase, mode, salt, hash[:iterations] || ITERATIONS)
        box.decrypt(iv, nonce, ciphertext)
      end

      attr_reader :salt

      # Initialize with an existing salt and iterations to allow
      # decryption.  Otherwise, creates new values for these, meaning
      # it creates an entirely new secret-box.
      def initialize(passphrase, mode=:aes, salt=SecureRandom.random_bytes(SALT_RANDOM_BYTES), iterations=nil)
        @salt = salt 
        @iterations = iterations || ITERATIONS + SecureRandom.random_number(ITERATIONS_WINDOW) 
        @mode = mode

        if @mode == :aes
          @key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(
            passphrase,
            @salt,
            # TODO: decide on a very safe work factor
            # https://www.owasp.org/index.php/Password_Storage_Cheat_Sheet
            #
            @iterations, # number of iterations
            KEY_SIZE * 2 # key length in bytes
          )

          @aes_key = @key[0, KEY_SIZE]
          @hmac_key = @key[KEY_SIZE, KEY_SIZE]
          @cipher = OpenSSL::Cipher.new(AES_CIPHER)
          @cipher.padding = 0
        elsif @mode == :nacl
          @key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(
            passphrase,
            @salt,
            # TODO: decide on a very safe work factor
            # https://www.owasp.org/index.php/Password_Storage_Cheat_Sheet
            #
            @iterations, # number of iterations
            KEY_SIZE     # key length in bytes
          )
          @box = RbNaCl::SecretBox.new(@key)
        end

      end

      def encrypt(plaintext, iv=@cipher.random_iv)
        @cipher.encrypt
        @cipher.iv = iv
        @cipher.key = @aes_key
        encrypted = @cipher.update(plaintext)
        encrypted << @cipher.final
        digest = OpenSSL::Digest::SHA256.new
        hmac_digest = OpenSSL::HMAC.digest(digest, @hmac_key, iv + encrypted)
        ciphertext = encrypted + hmac_digest
        {
          iterations: @iterations,
          salt: hex(@salt),
          iv: hex(iv),
          ciphertext: hex(ciphertext)
        }
      end

      def decrypt(iv, nonce, ciphertext)
        if @mode == :aes
          return decrypt_aes(iv, ciphertext)
        elsif @mode == :nacl
          return decrypt_nacl(nonce, ciphertext)
        end
        raise('Incompatible ciphertext')
      end

      def decrypt_aes(iv, ciphertext)
        mac, ctext = ciphertext[-KEY_SIZE, KEY_SIZE], ciphertext[0...-KEY_SIZE]
        digest = OpenSSL::Digest::SHA256.new
        hmac_digest = OpenSSL::HMAC.digest(digest, @hmac_key, iv + ctext)
        if hmac_digest != mac
          raise('Invalid authentication code - this ciphertext may have been tampered with.')
        end
        @cipher.decrypt
        @cipher.iv = iv
        @cipher.key = @aes_key
        decrypted = @cipher.update(ctext)
        decrypted << @cipher.final
      end

      def decrypt_nacl(nonce, ciphertext)
        @box.decrypt(nonce, ciphertext)
      end

    end

  end
end
