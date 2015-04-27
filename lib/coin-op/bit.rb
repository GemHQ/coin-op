require "bitcoin"

# bitcoin-ruby is not multi-network friendly.  It's also a hassle
# to tell what network you're using if you don't already know.
# This makes it a bit easier.
Bitcoin::NETWORKS.each do |name, definition|
  definition[:name] = name
end

module Bitcoin
  module OpenSSL_EC
    attach_function :d2i_ECDSA_SIG, [:pointer, :pointer, :long], :pointer
    attach_function :i2d_ECDSA_SIG, [:pointer, :pointer], :int
    attach_function :OPENSSL_free, :CRYPTO_free, [:pointer], :void
    attach_function :BN_rshift1, [:pointer, :pointer], :int
    attach_function :BN_sub, [:pointer, :pointer, :pointer], :int
    attach_function :BN_num_bits, [:pointer], :int
    
    def self.BN_num_bytes(ptr); (BN_num_bits(ptr) + 7) / 8; end

    # repack signature for OpenSSL 1.0.1k handling of DER signatures
    # https://github.com/bitcoin/bitcoin/pull/5634/files
    def self.repack_der_signature(signature)
      init_ffi_ssl

      return false if signature.empty?

      # New versions of OpenSSL will reject non-canonical DER signatures. de/re-serialize first.
      norm_der = FFI::MemoryPointer.new(:pointer)
      sig_ptr  = FFI::MemoryPointer.new(:pointer).put_pointer(0, FFI::MemoryPointer.from_string(signature))

      norm_sig = d2i_ECDSA_SIG(nil, sig_ptr, signature.bytesize)

      derlen = i2d_ECDSA_SIG(norm_sig, norm_der)
      ECDSA_SIG_free(norm_sig)
      return false if derlen <= 0

      ret = norm_der.read_pointer.read_string(derlen)
      OPENSSL_free(norm_der.read_pointer)

      ret
    end

    # Regenerate a DER-encoded signature such that the S-value complies with the BIP62
    # specification.
    #
    def self.signature_to_low_s(signature)
      init_ffi_ssl

      temp = signature.unpack("C*")
      length_r = temp[3]
      length_s = temp[5+length_r]
      sig = FFI::MemoryPointer.from_string(signature)

      # Calculate the lower s value
      s = BN_bin2bn(sig[6 + length_r], length_s, BN_new())
      eckey = EC_KEY_new_by_curve_name(NID_secp256k1)
      group, order, halforder, ctx = EC_KEY_get0_group(eckey), BN_new(), BN_new(), BN_CTX_new()

      EC_GROUP_get_order(group, order, ctx)
      BN_rshift1(halforder, order)
      if BN_cmp(s, halforder) > 0
        BN_sub(s, order, s)
      end

      BN_free(halforder)
      BN_free(order)
      BN_CTX_free(ctx)
      
      buf = FFI::MemoryPointer.new(:uint8, BN_num_bytes(s))
      BN_bn2bin(s, buf)
      length_s = BN_num_bytes(s)
      # p buf.read_string(length_s).unpack("H*")
      
      # Re-encode the signature in DER format
      sig = [0x30, 0, 0x02, length_r]
      sig.concat(temp.slice(4, length_r))
      sig << 0x02
      sig << length_s
      sig.concat(buf.read_string(length_s).unpack("C*"))
      sig[1] = sig.size - 2

      BN_free(s)
      EC_KEY_free(eckey)

      sig.pack("C*")
    end

  end

  module Util
    def verify_signature(hash, signature, public_key)
      key  = bitcoin_elliptic_curve
      key.public_key = ::OpenSSL::PKey::EC::Point.from_hex(key.group, public_key)
      signature = Bitcoin::OpenSSL_EC.repack_der_signature(signature)
      if signature
        key.dsa_verify_asn1(hash, signature)
      else
        false
      end
    rescue OpenSSL::PKey::ECError, OpenSSL::PKey::EC::Point::Error
      false
    end
  end

  class Key
    # Sign +data+ with the key.
    #  key1 = Bitcoin::Key.generate
    #  sig = key1.sign("some data")
    def sign(data)
      sig = @key.dsa_sign_asn1(data)
      if Script::is_low_der_signature?(sig)
        sig
      else
        Bitcoin::OpenSSL_EC.signature_to_low_s(sig)
      end
    end

    # Verify signature +sig+ for +data+.
    #  key2 = Bitcoin::Key.new(nil, key1.pub)
    #  key2.verify("some data", sig)
    def verify(data, sig)
      regenerate_pubkey unless @key.public_key
      sig = Bitcoin::OpenSSL_EC.repack_der_signature(sig)
      if sig
        @key.dsa_verify_asn1(data, sig)
      else
        false
      end
    end
  end

  class Script
    attr_reader :raw, :chunks, :debug, :stack

    # Loosely correlates with IsLowDERSignature() from interpreter.cpp
    def self.is_low_der_signature?(sig)
      s = sig.unpack("C*")

      length_r = s[3]
      length_s = s[5+length_r]
      s_val = s.slice(6 + length_r, length_s)

      # If the S value is above the order of the curve divided by two, its
      # complement modulo the order could have been used instead, which is
      # one byte shorter when encoded correctly.
      max_mod_half_order = [
        0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
        0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
        0x5d,0x57,0x6e,0x73,0x57,0xa4,0x50,0x1d,
        0xdf,0xe9,0x2f,0x46,0x68,0x1b,0x20,0xa0]

      compare_big_endian(s_val, [0]) > 0 &&
        compare_big_endian(s_val, max_mod_half_order) <= 0
    end

    # Compares two arrays of bytes
    def self.compare_big_endian(c1, c2)
      c1, c2 = c1.dup, c2.dup # Clone the arrays

      while c1.size > c2.size
        return 1 if c1.shift > 0
      end

      while c2.size > c1.size
        return -1 if c2.shift > 0
      end

      c1.size.times{|idx| return c1[idx] - c2[idx] if c1[idx] != c2[idx] }
      0
    end
  end

end

# BIP 32 Hierarchical Deterministic Wallets
require "money-tree"

# establish the namespace
module CoinOp
  module Bit
  end
end

require_relative "encodings"

# Wrappers
require_relative "bit/script"
require_relative "bit/output"
require_relative "bit/input"
require_relative "bit/transaction"
require_relative "bit/spendable"
require_relative "bit/fee"

# Augmented functionality
require_relative "bit/multi_wallet"

