require 'spec_helper'
require 'omniauth-linkedin-oauth2'

describe OmniAuth::Strategies::LinkedIn do
  subject { OmniAuth::Strategies::LinkedIn.new(nil) }

  it 'adds camelization for itself' do
    expect(OmniAuth::Utils.camelize('linkedin')).to eq('LinkedIn')
  end

  describe '#client' do
    it 'has correct LinkedIn site' do
      expect(subject.client.site).to eq('https://api.linkedin.com')
    end

    it 'has correct `authorize_url`' do
      expect(subject.client.options[:authorize_url]).to eq('https://www.linkedin.com/oauth/v2/authorization?response_type=code')
    end

    it 'has correct `token_url`' do
      expect(subject.client.options[:token_url]).to eq('https://www.linkedin.com/oauth/v2/accessToken')
    end
  end

  describe '#callback_path' do
    it 'has the correct callback path' do
      expect(subject.callback_path).to eq('/auth/linkedin/callback')
    end
  end

  describe '#uid' do
    before :each do
      allow(subject).to receive(:raw_info) { Hash['id' => 'uid'] }
    end

    it 'returns the id from raw_info' do
      expect(subject.uid).to eq('uid')
    end
  end

  describe '#info / #raw_info' do
    let(:access_token) { instance_double OAuth2::AccessToken }

    let(:parsed_response) { Hash[:foo => 'bar'] }

    let(:profile_endpoint) { '/v2/me?projection=(id,firstName,lastName,profilePicture(displayImage~:playableStreams))' }
    let(:email_address_endpoint) { '/v2/emailAddress?q=members&projection=(elements*(handle~))' }

    let(:email_address_response) { instance_double OAuth2::Response, parsed: parsed_response }
    let(:profile_response) { instance_double OAuth2::Response, parsed: parsed_response }

    before :each do
      allow(subject).to receive(:access_token).and_return access_token

      allow(access_token).to receive(:get)
        .with(email_address_endpoint)
        .and_return(email_address_response)

      allow(access_token).to receive(:get)
        .with(profile_endpoint)
        .and_return(profile_response)
    end

    context 'api_version is v1' do
      context 'and therefore has all the necessary fields' do
        it { expect(subject.info).to have_key :name }
        it { expect(subject.info).to have_key :email }
        it { expect(subject.info).to have_key :nickname }
        it { expect(subject.info).to have_key :first_name }
        it { expect(subject.info).to have_key :last_name }
        it { expect(subject.info).to have_key :location }
        it { expect(subject.info).to have_key :description }
        it { expect(subject.info).to have_key :image }
        it { expect(subject.info).to have_key :urls }
      end
    end

    context 'api_version is v2' do
      before :each do
        subject.stub(:options => double('options', :api_version => 'v2').as_null_object)
      end

      context 'and therefore has all the necessary fields' do
        it { expect(subject.info).to have_key :name }
        it { expect(subject.info).to have_key :nickname }
        it { expect(subject.info).to have_key :first_name }
        it { expect(subject.info).to have_key :last_name }
        it { expect(subject.info).to have_key :description }
        it { expect(subject.info).to have_key :image }
        it { expect(subject.info).to have_key :urls }
      end
    end
  end

  describe '#extra' do
    let(:raw_info) { Hash[:foo => 'bar'] }

    before :each do
      allow(subject).to receive(:raw_info).and_return raw_info
    end

    specify { expect(subject.extra['raw_info']).to eq raw_info }
  end

  describe '#access_token' do
    let(:expires_in) { 3600 }
    let(:expires_at) { 946688400 }
    let(:token) { 'token' }
    let(:refresh_token) { 'refresh_token' }
    let(:access_token) do
      instance_double OAuth2::AccessToken, :expires_in => expires_in,
        :expires_at => expires_at, :token => token, :refresh_token => refresh_token
    end

    before :each do
      allow(subject).to receive(:option_fields) { ['baz', 'qux'] }
    end

    context 'api_version is v1' do
      before :each do
        response = double('response', :parsed => { :foo => 'bar' })
        access_token = double('access token')
        expect(access_token).to receive(:get).with("/v1/people/~:(baz,qux)?format=json").and_return(response)
        allow(subject).to receive(:access_token) { access_token }
      end

      it 'returns parsed response from access token' do
        expect(subject.raw_info).to eq({ :foo => 'bar' })
      end
    end

    context 'api_version is v2' do
      before :each do
        response = double('response', :parsed => { :foo => 'bar' })
        access_token = double('access token')
        expect(access_token).to receive(:get).with("/v2/me?projection=(baz,qux)").and_return(response)
        allow(subject).to receive(:access_token) { access_token }
        subject.stub(:options => double('options', :api_version => 'v2').as_null_object)
      end

      it 'returns parsed response from access token' do
        expect(subject.raw_info).to eq({ :foo => 'bar' })
      end
    end
  end

  describe '#authorize_params' do
    describe 'scope' do
      before :each do
        allow(subject).to receive(:session).and_return({})
      end

      it 'sets default scope' do
        expect(subject.authorize_params['scope']).to eq('r_liteprofile r_emailaddress')
      end
    end
  end

  describe '#option_fields' do
    context 'api_version is v1' do
      it 'returns options fields' do
        subject.stub(:options => double('options', :fields => ['foo', 'bar'], :api_version => 'v1').as_null_object)
        expect(subject.send(:option_fields)).to eq(['foo', 'bar'])
      end

      it 'http avatar image by default' do
        subject.stub(:options => double('options', :fields => ['picture-url'], :api_version => 'v1'))
        allow(subject.options).to receive(:[]).with(:secure_image_url).and_return(false)
        expect(subject.send(:option_fields)).to eq(['picture-url'])
      end

      it 'https avatar image if secure_image_url truthy' do
        subject.stub(:options => double('options', :fields => ['picture-url'], :api_version => 'v1'))
        allow(subject.options).to receive(:[]).with(:secure_image_url).and_return(true)
        expect(subject.send(:option_fields)).to eq(['picture-url;secure=true'])
      end
    end

    context 'api_version is v2' do
      it 'returns options fields' do
        subject.stub(:options => double('options', :fields => ['foo', 'bar'], :api_version => 'v2').as_null_object)
        expect(subject.send(:option_fields)).to eq(['foo', 'bar'])
      end

      it 'converts picture-url to the profilePicture projection' do
        subject.stub(:options => double('options', :fields => ['picture-url'], :api_version => 'v2').as_null_object)
        expect(subject.send(:option_fields)).to eq(['profilePicture(displayImage~:playableStreams)'])
      end

      it 'converts first-name to the localizedFirstName projection' do
        subject.stub(:options => double('options', :fields => ['first-name'], :api_version => 'v2').as_null_object)
        expect(subject.send(:option_fields)).to eq(['localizedFirstName'])
      end

      it 'converts last-name to the localizedLastName projection' do
        subject.stub(:options => double('options', :fields => ['last-name'], :api_version => 'v2').as_null_object)
        expect(subject.send(:option_fields)).to eq(['localizedLastName'])
      end

      it 'converts industry to the industryName projection' do
        subject.stub(:options => double('options', :fields => ['industry'], :api_version => 'v2').as_null_object)
        expect(subject.send(:option_fields)).to eq(['industryName'])
      end

      it 'converts public-profile-url to the vanityName projection' do
        subject.stub(:options => double('options', :fields => ['public-profile-url'], :api_version => 'v2').as_null_object)
        expect(subject.send(:option_fields)).to eq(['vanityName'])
      end

      it 'ignores email-address' do
        subject.stub(:options => double('options', :fields => ['email-address'], :api_version => 'v2').as_null_object)
        expect(subject.send(:option_fields)).to eq([])
      end

      it 'ignores location' do
        subject.stub(:options => double('options', :fields => ['location'], :api_version => 'v2').as_null_object)
        expect(subject.send(:option_fields)).to eq([])
      end
    end
  end
end
