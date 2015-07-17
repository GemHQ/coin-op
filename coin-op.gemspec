require_relative 'lib/coin-op/version'

Gem::Specification.new do |s|
  s.name = 'coin-op'
  s.version = CoinOp::VERSION
  s.license = 'MIT'
  s.authors = [
    'Matthew King',
    'Julian Vergel de Dios',
    'Dustin Laurence',
    'James Larisch'
  ]
  s.email = [
    'automatthew@gmail.com',
    'julian@gem.co',
    'dustin@gem.co',
    'james@gem.co'
  ]
  s.homepage = 'https://github.com/GemHQ/coin-op'
  s.summary = 'Crypto currency classes in Ruby'
  s.description = 'A pretty, simple to use interface for all of the cryptocurrency libraries you love to use.'

  s.files = %w[
    LICENSE
    README.md
  ] + Dir['lib/**/*.rb']
  s.require_path = 'lib'

  # used with gem i coin-op -P HighSecurity
  s.cert_chain  = ['certs/jvergeldedios.pem']
  # Sign gem when evaluating spec with `gem` command
  #  unless ENV has set a SKIP_GEM_SIGNING
  if ($0 =~ /gem\z/) and not ENV.include?('SKIP_GEM_SIGNING')
    s.signing_key = File.join(Gem.user_home, '.ssh', 'gem-private_key.pem')
  end

  s.add_dependency('bitcoin-ruby', '0.0.6')
  s.add_dependency('money-tree', '~> 0.9')
  s.add_dependency('hashie', '~> 2.0')
  s.add_dependency('rbnacl-libsodium', '1.0.3')

  s.add_development_dependency('sequel', '~> 4.8')
  s.add_development_dependency('sqlite3', '~> 1.3')
  s.add_development_dependency('rspec')
  s.add_development_dependency('pry')
end

