require "bitcoin"

Bitcoin::NETWORKS[:dogecoin] = Bitcoin::NETWORKS[:litecoin].merge({
  project: :dogecoin,
  magic_head: "\xc0\xc0\xc0\xc0",
  address_version: "1e",
  p2sh_version: "16",
  privkey_version: "9e",
  default_port: 22556,
  protocol_version: 70003,
  max_money: 100_000_000_000 * Bitcoin::COIN,
  min_tx_fee: Bitcoin::COIN,
  min_relay_tx_fee: Bitcoin::COIN,
  free_tx_bytes: 26_000,
  dust: Bitcoin::COIN,
  per_dust_fee: true,
  coinbase_maturity: 30,
  coinbase_maturity_new: 240,
  reward_base: 500_000 * Bitcoin::COIN,
  reward_halving: 100_000,
  retarget_interval: 240,
  retarget_time: 14400, # 4 hours
  retarget_time_new: 60, # 1 minute
  target_spacing: 60, # block interval
  dns_seeds: [
    "seed.dogechain.info", 
    "seed.dogecoin.com",
  ],
  genesis_hash: "1a91e3dace36e2be3bf030a65679fe821aa1d6ef92e7c9902eb318182c355691",
  proof_of_work_limit: 0x1e0fffff,
  alert_pubkeys: [],
  known_nodes: [
    "daemons.chain.so",
    "bootstrap.chain.so",
  ],
  checkpoints: {
    0 => "1a91e3dace36e2be3bf030a65679fe821aa1d6ef92e7c9902eb318182c355691",
    42279 => "8444c3ef39a46222e87584ef956ad2c9ef401578bd8b51e8e4b9a86ec3134d3a",
    42400 => "557bb7c17ed9e6d4a6f9361cfddf7c1fc0bdc394af7019167442b41f507252b4",
    104679 => "35eb87ae90d44b98898fec8c39577b76cb1eb08e1261cfc10706c8ce9a1d01cf",
    128370 => "3f9265c94cab7dc3bd6a2ad2fb26c8845cb41cff437e0a75ae006997b4974be6",
    145000 => "cc47cae70d7c5c92828d3214a266331dde59087d4a39071fa76ddfff9b7bde72",
    165393 => "7154efb4009e18c1c6a6a79fc6015f48502bcd0a1edd9c20e44cd7cbbe2eeef1",
    186774 => "3c712c49b34a5f34d4b963750d6ba02b73e8a938d2ee415dcda141d89f5cb23a",
    199992 => "3408ff829b7104eebaf61fd2ba2203ef2a43af38b95b353e992ef48f00ebb190",
    225000 => "be148d9c5eab4a33392a6367198796784479720d06bfdd07bd547fe934eea15a",
    250000 => "0e4bcfe8d970979f7e30e2809ab51908d435677998cf759169407824d4f36460",
    270639 => "c587a36dd4f60725b9dd01d99694799bef111fc584d659f6756ab06d2a90d911",
    299742 => "1cc89c0c8a58046bf0222fe131c099852bd9af25a80e07922918ef5fb39d6742",
    323141 => "60c9f919f9b271add6ef5671e9538bad296d79f7fdc6487ba702bf2ba131d31d",
    339202 => "8c29048df5ae9df38a67ea9470fdd404d281a3a5c6f33080cd5bf14aa496ab03"
  },
  auxpow_chain_id: 0x0062,
  # Doge-specific hard-fork cutoffs
  difficulty_change_block: 145000,
  maturity_change_block: 145000,
  auxpow_start_block: 371337
})

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

