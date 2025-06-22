require 'rails_helper'

RSpec.describe SailingRepository do
  subject(:repository) { described_class.new }

  describe '#find_direct_sailings' do
    let(:origin_port) { 'CNSHA' }
    let(:destination_port) { 'NLRTM' }

    before do
      # Integration test - actual database calls
      FactoryBot.create(:sailing,
        origin_port: origin_port,
        destination_port: destination_port,
        sailing_code: 'ABCD'
      )
      FactoryBot.create(:sailing,
        origin_port: 'ESBCN',
        destination_port: destination_port,
        sailing_code: 'EFGH'
      )
    end

    it 'returns direct sailings between origin and destination ports' do
      result = repository.find_direct_sailings(origin_port, destination_port)

      expect(result.count).to eq(1)
      expect(result.first.sailing_code).to eq('ABCD')
    end

    it 'includes associated rates in the query' do
      sailing = Sailing.find_by(sailing_code: 'ABCD')
      FactoryBot.create(:rate, sailing: sailing)

      result = repository.find_direct_sailings(origin_port, destination_port)

      # Verify that the rate association is included by checking that it's loaded
      sailing_with_rate = result.first
      expect(sailing_with_rate.association(:rate).loaded?).to be true
    end
  end

  describe '#find_or_create_sailing_with_rate' do
    let(:sailing_data) do
      {
        'sailing_code' => 'TEST123',
        'origin_port' => 'CNSHA',
        'destination_port' => 'NLRTM',
        'departure_date' => '2022-01-29',
        'arrival_date' => '2022-02-15'
      }
    end

    let(:rate_data) do
      {
        'rate' => '589.30',
        'rate_currency' => 'USD'
      }
    end

    context 'when sailing does not exist' do
      it 'creates new sailing with rate' do
        expect { repository.find_or_create_sailing_with_rate(sailing_data, rate_data) }
          .to change(Sailing, :count).by(1)
          .and change(Rate, :count).by(1)
      end

      it 'sets sailing attributes correctly' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, rate_data)

        expect(sailing.sailing_code).to eq('TEST123')
        expect(sailing.origin_port).to eq('CNSHA')
        expect(sailing.destination_port).to eq('NLRTM')
        expect(sailing.departure_date).to eq(Date.parse('2022-01-29'))
        expect(sailing.arrival_date).to eq(Date.parse('2022-02-15'))
      end

      it 'creates rate with correct money amount' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, rate_data)

        expect(sailing.rate.amount).to eq(Money.new(58930, 'USD'))
        expect(sailing.rate.currency).to eq('USD')
      end
    end

    context 'when sailing already exists' do
      before do
        FactoryBot.create(:sailing, sailing_code: 'TEST123')
      end

      it 'does not create duplicate sailing' do
        expect { repository.find_or_create_sailing_with_rate(sailing_data, rate_data) }
          .not_to change(Sailing, :count)
      end

      it 'creates rate for existing sailing' do
        expect { repository.find_or_create_sailing_with_rate(sailing_data, rate_data) }
          .to change(Rate, :count).by(1)
      end
    end

    context 'when rate_data is nil' do
      it 'creates sailing without rate' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, nil)

        expect(sailing).to be_persisted
        expect(sailing.rate).to be_nil
      end
    end
  end
end
