# spec/repositories/exchange_rate_repository_spec.rb
require 'rails_helper'

RSpec.describe ExchangeRateRepository do
  subject(:repository) { described_class.new }

  describe '#load_rates_incrementally' do
    let(:exchange_rates_data) do
      {
        '2022-01-29' => {
          'usd' => 1.1138,
          'jpy' => 130.85
        },
        '2022-01-30' => {
          'usd' => 1.1156,
          'jpy' => 132.97
        }
      }
    end

    context 'with correct data' do
      it 'creates exchange rates for all currencies and dates with correct attributes' do
        expect { repository.load_rates_incrementally(exchange_rates_data) }
          .to change(ExchangeRate, :count).by(4)

        # Verify correct attributes
        usd_rate = ExchangeRate.find_by(
          departure_date: Date.parse('2022-01-29'),
          currency: 'usd'
        )
        expect(usd_rate.rate).to eq(1.1138)

        jpy_rate = ExchangeRate.find_by(
          departure_date: Date.parse('2022-01-30'),
          currency: 'jpy'
        )
        expect(jpy_rate.rate).to eq(132.97)
      end

      it 'handles existing rates without creating duplicates or without updating existing values' do
        create(:exchange_rate,
          departure_date: Date.parse('2022-01-29'),
          currency: 'usd',
          rate: 1.0000
        )

        expect { repository.load_rates_incrementally(exchange_rates_data) }
          .to change(ExchangeRate, :count).by(3)

        existing_rate = ExchangeRate.find_by(
          departure_date: Date.parse('2022-01-29'),
          currency: 'usd'
        )
        expect(existing_rate.rate).to eq(1.0000)
      end

      it 'handles empty data gracefully' do
        expect { repository.load_rates_incrementally({}) }
          .not_to change(ExchangeRate, :count)
      end
    end

    context 'negative scenarios' do
      it 'raises error when data format is invalid' do
        invalid_data = { 'invalid_date' => 'not_a_hash' }

        expect {
          repository.load_rates_incrementally(invalid_data)
        }.to raise_error(NoMethodError, /undefined method 'each'/)
      end

      it 'raises error when date format is invalid' do
        invalid_date_data = {
          'invalid_date_string' => { 'usd' => 1.1138 }
        }

        expect {
          repository.load_rates_incrementally(invalid_date_data)
        }.to raise_error(ArgumentError, /invalid date/)
      end
    end
  end
end
