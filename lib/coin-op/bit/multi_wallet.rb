module CoinOp::Bit

  class MultiWallet
    include CoinOp::Encodings

    def self.generate(names)
      masters = {}
      names.each do |name|
        name = name.to_sym
        masters[name] = MoneyTree::Master.new
      end
      self.new(private: masters)
    end

    attr_reader :trees

    def initialize(options)
      @private_trees = {}
      @public_trees = {}
      @trees = {}

      # FIXME: we should allow this.
      # if !private_trees
      #   raise "Must supply :private"
      # end

      if private_trees = options[:private]
        private_trees.each do |name, arg|
          name = name.to_sym
          @private_trees[name] = @trees[name] = self.get_node(arg)
        end
      end

      if public_trees = options[:public]
        public_trees.each do |name, arg|
          name = name.to_sym
          @public_trees[name] = @trees[name] = self.get_node(arg)
        end
      end
    end

    def get_node(arg)
      case arg
      when MoneyTree::Node
        arg
      when String
        MoneyTree::Node.from_bip32(arg)
      else
        raise "Unusable type: #{node.class}"
      end
    end

    def drop(*names)
      names = names.map(&:to_sym)
      options = {:private => {}, :public => {}}
      @private_trees.each do |name, node|
        unless names.include?(name.to_sym)
          options[:private][name] = node
        end
      end
      @public_trees.each do |name, node|
        unless names.include?(name.to_sym)
          options[:private][name] = node
        end
      end
      self.class.new options
    end

    def drop_private(*names)
      names.each do |name|
        name = name.to_sym
        tree = @private_trees.delete(name)
        serialized_priv = tree.to_bip32
        @public_trees[name] = MoneyTree::Master.from_bip32(serialized_priv)
      end
    end

    def import(addresses)
      addresses.each do |name, address|
        node = MoneyTree::Master.from_bip32(address)
        if node.private_key
          @private_trees[name] = node
        else
          @public_trees[name] = node
        end
      end
    end

    def private_seed(name, network:)
      raise "No such node: '#{name}'" unless (node = @private_trees[name.to_sym])
      node.to_bip32(:private, network: network)
    end

    alias_method :private_address, :private_seed

    def public_seed(name, network:)
      name = name.to_sym
      if node = (@public_trees[name] || @private_trees[name])
        node.to_bip32(network: network)
      else
        raise "No such node: '#{name}'"
      end
    end

    def private_seeds(network:)
      out = {}
      @private_trees.each do |name, tree|
        out[name] = self.private_address(name, network: network)
      end
      out
    end

    def public_seeds(network:)
      out = {}
      @private_trees.each do |name, node|
        out[name] = node.to_bip32(network: network)
      end
      out
    end

    alias_method :public_address, :public_seed
    alias_method :private_addresses, :private_seeds
    alias_method :public_addresses, :public_seeds

    def path(path)
      options = {
        :path => path,
        :private => {},
        :public => {},
      }
      @private_trees.each do |name, node|
        options[:private][name] = node.node_for_path(path)
      end
      @public_trees.each do |name, node|
        options[:public][name] = node.node_for_path(path)
      end

      MultiNode.new(options)
    end

    def address(path)
      path(path).address
    end

    def valid_output?(output)
      if path = output.metadata.wallet_path
        node = self.path(path)
        node.p2sh_script.to_s == output.script.to_s
      else
        true
      end
    end

    # Takes a Transaction ready to be signed.
    #
    # Returns an Array of signature dictionaries.
    def signatures(transaction, names: [:primary])
      transaction.inputs.map do |input|
        path = input.output.metadata[:wallet_path]
        node = self.path(path)
        sig_hash = transaction.sig_hash(input, node.script)
        node.signatures(sig_hash, names: names)
      end
    end

    def set_sig_hashes(transaction)
      transaction.inputs.each do |input|
        path = input.output.metadata[:wallet_path]
        node = self.path(path)
        input.binary_sig_hash = transaction.sig_hash(input, node.script)
      end
    end

    # Takes a Transaction and any number of Arrays of signature dictionaries.
    # Each sig_dict in an Array corresponds to the Input with the same index.
    #
    # Uses the combined signatures from all the signers to generate and set
    # the script_sig for each Input.
    #
    # Returns the transaction.
    def authorize(transaction, *signers)
      transaction.set_script_sigs *signers do |input, *sig_dicts|
        node = self.path(input.output.metadata[:wallet_path])
        signatures = combine_signatures(*sig_dicts)
        node.script_sig(signatures)
      end
      transaction
    end

    # Takes any number of "signature dictionaries", which are Hashes where
    # the keys are tree names, and the values are base58-encoded signatures
    # for a single input.
    #
    # Returns an Array of the signatures in binary, sorted by their tree names.
    def combine_signatures(*sig_dicts)
      combined = {}
      sig_dicts.each do |sig_dict|
        sig_dict.each do |tree, signature|
          decoded_sig = decode_base58(signature)
          low_s_der_sig = Bitcoin::Script.is_low_der_signature?(decoded_sig) ?
            decoded_sig : Bitcoin::OpenSSL_EC.signature_to_low_s(decoded_sig)
          combined[tree] = Bitcoin::OpenSSL_EC.repack_der_signature(low_s_der_sig)
        end
      end

      # Order of signatures is important for validation, so we always
      # sort public keys and signatures by the name of the tree
      # they belong to.
      combined.sort_by { |tree, value| tree }.map { |tree, sig| sig }
    end

  end

  class MultiNode
    include CoinOp::Encodings

    CODE_TO_NETWORK = {
      0 => :bitcoin,
      1 => :testnet3,
      2 => :litecoin,
      3 => :dogecoin
    }

    attr_reader :path, :private, :public, :keys, :public_keys
    def initialize(options)
      @path = options[:path]

      @keys = {}
      @public_keys = {}
      @private = options[:private]
      @public = options[:public]

      @private.each do |name, node|
        key = Bitcoin::Key.new(node.private_key.to_hex, node.public_key.to_hex)
        @keys[name] = key
        @public_keys[name] = key
      end
      @public.each do |name, node|
        @public_keys[name] = Bitcoin::Key.new(nil, node.public_key.to_hex)
      end
    end

    def network
      CODE_TO_NETWORK.fetch(@path.split('/')[2].to_i)
    end

    def script(m=2)
      # m of n
      keys = @public_keys.sort_by {|name, key| name }.map {|name, key| key.pub }
      Script.new(public_keys: keys, needed: m, network: network)
    end

    def address
      self.script.p2sh_address
    end

    alias_method :p2sh_address, :address

    def p2sh_script
      Script.new(:address => self.script.p2sh_address, network: network)
    end

    def signatures(value, names:)
      out = {}
      @keys.each do |name, key|
        next unless names.include?(name)
        out[name] = base58(key.sign(value))
      end
      out
    end

    def script_sig(signatures)
      self.script.p2sh_sig(:signatures => signatures)
    end

  end


end
