
module CoinOp::Bit

  # A wrapper class to make it easier to read and write Bitcoin scripts.
  # Provides a sane #to_json method.
  class Script
    include CoinOp::Encodings

    # Accessor for the "native" ::Bitcoin::Script script instance
    attr_reader :native

    # Takes either a String or a Hash as its argument.
    #
    # A String argument will be parsed as a human readable script.
    #
    # A Hash argument specifies a script using one of several possible
    # keys:
    #
    # * :string
    # * :blob
    # * :hex
    # * :address
    # * :public_key
    # * :public_keys, :needed
    # * :signatures
    #
    # The name of the crypto-currency network may also be specified.  It
    # defaults to :testnet3.  Names supplied in this manner must correspond
    # to the names in the ::Bitcoin::NETWORKS Hash.
    def initialize(options)
      # Doing the rescue in case the input argument is a String.
      network_name = (options[:network] || :testnet3) rescue :testnet3
      @network = Bitcoin::NETWORKS[network_name]
      raise Error if network_name != :bitcoin
      Bitcoin.network = network_name
      puts 'AHHHHHHHHHHHHHHHHHHHHHH'
      puts Bitcoin.network

      # literals
      if options.is_a? String
        @blob = Bitcoin::Script.binary_from_string options
      elsif string = options[:string]
        @blob = Bitcoin::Script.binary_from_string string
      elsif options[:blob]
        @blob = options[:blob]
      elsif options[:hex]
        @blob = decode_hex(options[:hex])
      # arguments for constructing
      else
        if address = options[:address]
          unless Bitcoin::valid_address?(address)
            raise ArgumentError, "Invalid address: #{address}"
          end
          @blob = Bitcoin::Script.to_address_script(address)
        elsif public_key = options[:public_key]
          @blob = Bitcoin::Script.to_pubkey_script(public_key)
        elsif (keys = options[:public_keys]) && (needed = options[:needed])
          @blob = Bitcoin::Script.to_multisig_script(needed, *keys)
        elsif signatures = options[:signatures]
          @blob = Bitcoin::Script.to_multisig_script_sig(*signatures)
        else
          raise ArgumentError
        end
      end

      @hex = hex(@blob)
      @native = Bitcoin::Script.new @blob
      @string = @native.to_string
    end

    def address
      @native.get_address
    end

    def to_s
      @string
    end

    def to_hex
      @hex
    end

    def to_blob
      @blob
    end

    alias_method :to_binary, :to_blob

    def type
      case self.native.type
      when :hash160
        # Pay to address, because an "address" is really just the hash
        # of a public key.
        :pubkey_hash
      when :p2sh
        # Pay to Script Hash
        :script_hash
      else
        self.native.type
      end
    end

    def to_hash
      {
        :type => self.type,
        :string => self.to_s
      }
    end

    def to_json(*a)
      self.to_hash.to_json(*a)
    end

    def hash160
      Bitcoin.hash160(@hex)
    end

    # Generate the script that uses a P2SH address.
    # Used for an Output's scriptPubKey value.  Not much used, and
    # can probably be removed, as I think it is equivalent to
    # Script.new :address => some_p2sh_address
    def p2sh_script
      self.class.new Bitcoin::Script.to_p2sh_script(self.hash160)
    end

    def p2sh_address
      Bitcoin.encode_address(self.hash160, Bitcoin::NETWORKS[@network[:name]][:p2sh_version])
    end

    # Generate a P2SH script_sig for the current script, using the
    # supplied options, which will, in the case of a multisig input,
    # be {:signatures => array_of_signatures}.
    def p2sh_sig(options)
      string = Script.new(options).to_s
      Bitcoin::Script.binary_from_string("#{string} #{self.to_hex}")
    end

  end

end
