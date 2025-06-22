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

    it 'creates exchange rates for all currencies and dates' do
      expect { repository.load_rates_incrementally(exchange_rates_data) }
        .to change(ExchangeRate, :count).by(4)
    end

    it 'creates rates with correct attributes' do
      repository.load_rates_incrementally(exchange_rates_data)

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

    context 'when exchange rate already exists' do
      before do
        FactoryBot.create(:exchange_rate,
          departure_date: Date.parse('2022-01-29'),
          currency: 'usd',
          rate: 1.0000
        )
      end

      it 'does not create duplicate exchange rate' do
        expect { repository.load_rates_incrementally(exchange_rates_data) }
          .to change(ExchangeRate, :count).by(3)
      end

      it 'does not update existing rate' do
        repository.load_rates_incrementally(exchange_rates_data)

        existing_rate = ExchangeRate.find_by(
          departure_date: Date.parse('2022-01-29'),
          currency: 'usd'
        )
        expect(existing_rate.rate).to eq(1.0000)
      end
    end
  end
end
