require 'rails_helper'

RSpec.describe DataRepository do
  subject(:repository) { described_class.new }

  let(:json_data) do
    {
      sailings: [
        {
          'origin_port' => 'CNSHA',
          'destination_port' => 'NLRTM',
          'departure_date' => '2022-02-01',
          'arrival_date' => '2022-03-01',
          'sailing_code' => 'ABCD'
        }
      ],
      rates: [
        {
          'sailing_code' => 'ABCD',
          'rate' => '589.30',
          'rate_currency' => 'USD'
        }
      ],
      exchange_rates: {
        '2022-02-01' => {
          'usd' => 1.126
        }
      }
    }.to_json
  end

  describe '#load_from_json' do
    it 'loads sailings, rates, and exchange rates in a transaction' do
      expect { repository.load_from_json(json_data) }
        .to change(Sailing, :count).by(1)
        .and change(Rate, :count).by(1)
        .and change(ExchangeRate, :count).by(1)
    end

    it 'creates properly associated sailing and rate' do
      repository.load_from_json(json_data)

      sailing = Sailing.find_by(sailing_code: 'ABCD')
      expect(sailing.rate.amount).to eq(Money.new(58930, 'USD'))
    end

    context 'when JSON is malformed' do
      let(:invalid_json) { '{ invalid json }' }

      it 'raises JSON parse error' do
        expect { repository.load_from_json(invalid_json) }
          .to raise_error(JSON::ParserError)
      end
    end

    context 'when database error occurs' do
      before do
        allow(Sailing).to receive(:find_or_create_by).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'rolls back transaction' do
        sailing_count = Sailing.count
        rate_count = Rate.count
        exchange_rate_count = ExchangeRate.count

        expect {
          repository.load_from_json(json_data)
        }.to raise_error(ActiveRecord::RecordInvalid)

        expect(Sailing.count).to eq(sailing_count)
        expect(Rate.count).to eq(rate_count)
        expect(ExchangeRate.count).to eq(exchange_rate_count)
      end
    end
  end

  describe '#find_direct_sailings' do
    let(:sailing_repository) { instance_double(SailingRepository) }
    let(:origin_port) { 'CNSHA' }
    let(:destination_port) { 'NLRTM' }

    before do
      allow(SailingRepository).to receive(:new).and_return(sailing_repository)
    end

    it 'delegates to sailing repository' do
      expected_result = [ FactoryBot.build_stubbed(:sailing) ]

      expect(sailing_repository)
        .to receive(:find_direct_sailings)
        .with(origin_port, destination_port)
        .and_return(expected_result)

      result = repository.find_direct_sailings(origin_port, destination_port)
      expect(result).to eq(expected_result)
    end
  end
end
