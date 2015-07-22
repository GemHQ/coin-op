begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

task :release_checksum do
  require 'digest/sha2'
  built_gem_path = "coin-op-#{CoinOp::VERSION}.gem" 
  checksum = Digest::SHA512.new.hexdigest(File.read(built_gem_path))
  checksum_path = "checksum/#{built_gem_path}.sha512"
  File.open(checksum_path, 'w' ) {|f| f.write(checksum) }
end
