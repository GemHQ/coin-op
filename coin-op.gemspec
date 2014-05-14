Gem::Specification.new do |s|
  s.name = "coin-op"
  s.version = "0.1.0"
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

  s.files = %w[
    LICENSE
    README.md
  ] + Dir["lib/**/*.rb"]
  s.require_path = "lib"

  s.add_dependency("bitcoin-ruby", "0.0.5")
  s.add_dependency("money-tree", "~> 0.8")
  s.add_dependency("rbnacl")
  s.add_dependency("http")

  s.add_development_dependency("starter", "0.1.12")
  s.add_development_dependency("sequel", "~> 4.8")
  s.add_development_dependency("sqlite3", "~> 1.3")
  s.add_development_dependency("rspec")
  s.add_development_dependency("factory_girl")
  s.add_development_dependency("pry-debugger")
end

