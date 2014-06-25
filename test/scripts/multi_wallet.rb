require_relative "../setup"
require "yaml"

require "coin-op/bit"
include CoinOp::Bit
include CoinOp::Encodings


def dig(s)
  Digest::SHA256.digest(s)
end

wallet = MultiWallet.generate [:backup, :primary, :cosigner]

paths = {}
%w[ m/0/0/0  m/1/1/1 ].each do |path|
  node = wallet.path(path)
  digest = dig(dig("smurfs"))
  key = node.keys[:primary]
  sig = hex(node.sign(:primary, digest))

  paths[path] = {
    "address" => node.address,
    "multisig_script" => node.script.to_s,
    "multisig_hash160" => node.script.hash160,
    "p2sh_script" => node.p2sh_script.to_s,
    "primary_address" => key.addr,
    "primary_seed" => node.private[:primary].to_serialized_address(:private),
    "primary_hex" => key.priv,
    "digest" => hex(digest),
    "primary_signature" => sig
  }
end

data = {
  "private" => {
    "backup" => wallet.private_seed(:backup),
    "cosigner" => wallet.private_seed(:cosigner),
    "primary" => wallet.private_seed(:primary),
  },
  "public" => {
    "backup" => wallet.public_seed(:backup),
    "cosigner" => wallet.public_seed(:cosigner),
    "primary" => wallet.public_seed(:primary),
  },
  "paths" => paths
}

File.open "test/data/wallet.yaml", "w" do |f|
  f.puts(data.to_yaml)
end

