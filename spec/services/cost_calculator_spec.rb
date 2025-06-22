require 'rails_helper'

RSpec.describe CostCalculator do
  let(:calculator) { described_class.new }

  describe 'inheritance' do
    it 'inherits from JourneyCalculator' do
      expect(described_class.superclass).to eq(JourneyCalculator)
    end

    it 'inherits valid_connection? method' do
      expect(calculator).to respond_to(:valid_connection?)
    end
  end

  describe '#convert_to_eur_cents' do
    let(:departure_date) { Date.parse('2022-02-16') }
    let(:exchange_rate) { build_stubbed(:exchange_rate, rate: 1.1482) }

    before do
      allow(ExchangeRate).to receive(:for_departure_date_and_currency)
        .with(departure_date, 'USD')
        .and_return(exchange_rate)
    end

    context 'when currency is already EUR' do
      it 'returns amount unchanged' do
        result = calculator.convert_to_eur_cents(10000, 'EUR', departure_date)
        expect(result).to eq(10000)
      end
    end

    context 'when converting from USD' do
      it 'converts using exchange rate' do
        result = calculator.convert_to_eur_cents(6996, 'USD', departure_date)
        expect(result).to eq(6093) # 6996 / 1.1482 = 6092.9 rounded to 6093
      end
    end

    context 'when exchange rate not found' do
      before do
        allow(ExchangeRate).to receive(:for_departure_date_and_currency)
          .with(departure_date, 'USD')
          .and_return(nil)
      end

      it 'returns 0' do
        result = calculator.convert_to_eur_cents(6996, 'USD', departure_date)
        expect(result).to eq(0)
      end
    end
  end
end
