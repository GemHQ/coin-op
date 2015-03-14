require_relative 'lib/coin-op/version'

Gem::Specification.new do |s|
  s.name = "coin-op"
  s.version = CoinOp::VERSION
  s.license = "MIT"
  s.authors = [
    "Matthew King"
  ]
  s.email = [
    "matthew@bitvault.io",
    "dustin@bitvault.io",
    "julian@bitvault.io"
  ]
  s.homepage = "https://github.com/BitVault/coin-op"
  s.summary = "Crypto currency classes in Ruby"
  s.description = "A pretty, simple to use interface for all of the cryptocurrency libraries you love to use."

  s.files = %w[
    LICENSE
    README.md
  ] + Dir["lib/**/*.rb"]
  s.require_path = "lib"

  s.add_dependency("bitcoin-ruby", "0.0.6")
  s.add_dependency("money-tree", "~> 0.8")
  s.add_dependency("rbnacl-libsodium", "~> 1.0")
  s.add_dependency("hashie", "~> 3.4")

  s.add_development_dependency("starter", "0.1.12")
  s.add_development_dependency("sequel", "~> 4.8")
  s.add_development_dependency("sqlite3", "~> 1.3")
  s.add_development_dependency("minitest-reporters", "~> 1.0")
end

