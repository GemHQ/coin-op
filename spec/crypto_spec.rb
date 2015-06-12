require 'spec_helper'

describe CoinOp::Crypto::PassphraseBox do
  describe 'encryption & decryption' do
    xit 'd(e(C)) should == C' do
      plain = '0123456789abcdef'
      ct = CoinOp::Crypto::PassphraseBox.encrypt('passphrase', plain)
      decrypted = CoinOp::Crypto::PassphraseBox.decrypt('passphrase', ct)
      expect(decrypted).to eq plain
    end
  end

  context 'coinop py test cases' do

    let!(:examples) do
      [
        [
          'asdfasdf', 'hellohellohello!',
          {ciphertext: 'e64cd877f968c408f9a0a2dbcf8e14667ef825c4349e1822ac4896a2553a751ec2346a8321027a3f947243c011025163',
           salt: '2eb78d2e7331e8462847a00f325d94b5',
           iterations: 97917,
           iv: '1bc9947601b4292059d4da59852dba30'}
        ],
        [
          'veryveryveryveryverylongpassphrase', 'hellohellohello!',
          {ciphertext: '718877e7aed7ef43c8aefbfce3a856b4a85a092cafc88a85a22a14c7ce632ac3f83beef10ac0797441209039ebd947c2',
           salt: 'e713895c90c226cb4d46c4ba4ac60371',
           iterations: 99307,
           iv: '680546fd230d044778c9e7da09712946'}
        ],
        [
          'veryveryveryveryverylongpassphrase', 'andaveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryvery
             veryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryvery
             veryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryvery
             veryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryvery
             veryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryvery
             veryveryveryveryveryveryveryveryveryveryveryveryveryveryverylongmessage!'.delete(' ').delete("\n"),
             {ciphertext: '67dfb9d2fb4c6f98b579e24c17e41ee97349e44b71f343e5deed3ae876172e72b703cd4235120eb83d76c58eca1ead5d434a
              4faa881ba473d97a2adc7825e0a5817aa254facfb47ce58937faa8b0a6aee0767db66c0ecd5957f080d4aaf58cddb6abe3114827b1dcac13276
              9b9c05c01bc50766330da25a6d507264df33f2d447a4c26ed161ca88bfa7cffa281a382df415d3da697ede4498c0edcfcb199338c78570c05b9303
              e905b42ed0fec63749425c4317465e6a927224970ee2d25a03b77ff53d4cfb40957ef65e3c8abb04e4411c0bf1f82d75e829ba247e50f94705fab4
              e3d085a9ebc581904771040af330ddb36f33c403447a79848d0fc15a817b7b8c06cb4e90c95e46d26733079942bebce2c28ed190e4a9bd3a2e520e8
              5da52111a34c492e6afbe5dec4e877926c16993e645b12220865e42b3be1b95bde1d29604288327ab277ca1fc0088db0b2808a00062491d9afb4211
              2554f8a935e4250e68a949534cb22305e71eba051e12ee1ff58b76b365836868e456ad72da5b6f185fa8bf144f7487331b2ff9c3000cce04344716
              6875190f0b9dd914dd80e34b45174f2a507c4bb37a48461bba25296213fca4a440703211d1f28341cceeaa6d3b05ee5d14219d3d0785d425c0ed422b2
              9f0832be3602985dacaaafd553cbc3caedae260d75a0ec24e97eb28edb1e3b913996e596219d4dc4192ab8abc9a200c0add51c769efc873ed8dde4ab
              1616d08418632508480856882d8356f4c3f895ac98a9742bf55448f2c47c5dba9f21ad4997828a673e115a94f9dc752ef507ccbf44db0f1d87b69e78
              7fb3377a53ee358752015ad34f52885f6f4fe348d740f6fec7a26a1a01543d2236f4b863cfedb620'.delete(' ').delete("\n"),
              salt: 'bd50cef8b0223bda3553dd507b4fcfa5',
              iterations: 93363,
              iv: 'ea4070d91a9463591411f6da76d05201'}
        ]
      ]
    end

    it 'should be associative' do
      examples.each do |pass, plaintext, encrypted|
        enc = CoinOp::Crypto::PassphraseBox.encrypt(pass, plaintext)
        dec = CoinOp::Crypto::PassphraseBox.decrypt(pass, enc)
        stored_dec = CoinOp::Crypto::PassphraseBox.decrypt(pass, encrypted)
        expect(plaintext).to eq dec
        expect(dec).to eq stored_dec
      end
    end
  end
end
