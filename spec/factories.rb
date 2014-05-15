FactoryGirl.define do
  factory :output do
    value 21_000_000
    script 'OP_DUP OP_HASH160 7b936f13a9a2f0f2c30520c5cb24bc76a148d696 OP_EQUALVERIFY OP_CHECKSIG'

    initialize_with { new(attributes) }
  end

  factory :transaction do

  end

  factory :input do
    initialize_with { new(attributes) }
  end

  factory :script do
    string 'OP_DUP OP_HASH160 7b936f13a9a2f0f2c30520c5cb24bc76a148d696 OP_EQUALVERIFY OP_CHECKSIG'
    initialize_with { new(attributes) }
  end

  factory :native_transaction, class: Bitcoin::Protocol::Tx do
    initialize_with { new(attributes) }
  end
end