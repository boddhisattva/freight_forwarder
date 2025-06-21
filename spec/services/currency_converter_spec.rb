require 'rails_helper'

RSpec.describe CurrencyConverter, type: :service do
  subject(:converter) { described_class.new }

  describe '#convert_to_eur' do
    let(:departure_date) { Date.parse('2022-01-29') }

    context 'when currency is EUR' do
      it 'returns the same money object' do
        money = Money.new(10000, 'EUR')

        result = converter.convert_to_eur(money, departure_date)

        expect(result).to eq(money)
      end
    end

    context 'when currency is USD' do
      before do
        @exchange_rate = build_stubbed(:exchange_rate,
          departure_date: departure_date,
          currency: 'usd',
          rate: 1.1138
        )

        allow(ExchangeRate).to receive(:for_departure_date_and_currency)
          .with(departure_date, 'USD')
          .and_return(@exchange_rate)
      end

      it 'converts USD to EUR using exchange rate' do
        money = Money.new(111380, 'USD') # $1113.80

        result = converter.convert_to_eur(money, departure_date)

        expect(result.currency.to_s).to eq('EUR')
        expect(result.cents).to eq(100000) # €1000.00 (111380 / 1.1138)
      end

      it 'rounds to nearest cent' do
        money = Money.new(111381, 'USD') # $1113.81

        result = converter.convert_to_eur(money, departure_date)

        expect(result.cents).to eq(100001) # €1000.01 (rounded)
      end
    end

    context 'when currency is JPY' do
      before do
        @exchange_rate = build_stubbed(:exchange_rate,
          departure_date: departure_date,
          currency: 'jpy',
          rate: 130.85
        )

        allow(ExchangeRate).to receive(:for_departure_date_and_currency)
          .with(departure_date, 'JPY')
          .and_return(@exchange_rate)
      end

      it 'converts JPY to EUR using exchange rate' do
        money = Money.new(13085000, 'JPY') # ¥130,850

        result = converter.convert_to_eur(money, departure_date)

        expect(result.currency.to_s).to eq('EUR')
        expect(result.cents).to eq(100000) # €1000.00
      end
    end

    context 'when exchange rate does not exist' do
      before do
        allow(ExchangeRate).to receive(:for_departure_date_and_currency)
          .and_return(nil)
      end

      it 'raises an error for missing exchange rate' do
        money = Money.new(10000, 'USD')
        missing_date = Date.parse('2022-12-31')

        expect {
          converter.convert_to_eur(money, missing_date)
        }.to raise_error(/No exchange rate found for USD on #{missing_date}/)
      end

      it 'raises an error for unsupported currency' do
        money = Money.new(10000, 'GBP')

        expect {
          converter.convert_to_eur(money, departure_date)
        }.to raise_error(/No exchange rate found for GBP/)
      end
    end

    context 'with Money::Currency object' do
      before do
        @exchange_rate = build_stubbed(:exchange_rate,
          departure_date: departure_date,
          currency: 'usd',
          rate: 1.1138
        )

        allow(ExchangeRate).to receive(:for_departure_date_and_currency)
          .with(departure_date, 'USD')
          .and_return(@exchange_rate)
      end

      it 'handles Money::Currency properly' do
        money = Money.new(111380, 'USD')
        # money.currency returns Money::Currency object, not string

        expect {
          converter.convert_to_eur(money, departure_date)
        }.not_to raise_error
      end
    end

    context 'with different date formats' do
      before do
        @exchange_rate = build_stubbed(:exchange_rate,
          departure_date: Date.parse('2022-02-01'),
          currency: 'usd',
          rate: 1.126
        )

        allow(ExchangeRate).to receive(:for_departure_date_and_currency)
          .with(Date.parse('2022-02-01'), 'USD')
          .and_return(@exchange_rate)

        allow(ExchangeRate).to receive(:for_departure_date_and_currency)
          .with('2022-02-01', 'USD')
          .and_return(@exchange_rate)
      end

      it 'works with Date object' do
        money = Money.new(112600, 'USD')
        date = Date.parse('2022-02-01')

        result = converter.convert_to_eur(money, date)

        expect(result.cents).to eq(100000)
      end

      it 'works with DateTime object' do
        money = Money.new(112600, 'USD')
        datetime = DateTime.parse('2022-02-01 10:30:00')

        result = converter.convert_to_eur(money, datetime)

        expect(result.cents).to eq(100000)
      end

      it 'works with string date' do
        money = Money.new(112600, 'USD')
        date_string = '2022-02-01'

        result = converter.convert_to_eur(money, date_string)

        expect(result.cents).to eq(100000)
      end
    end

    context 'with very small amounts' do
      before do
        @exchange_rate = build_stubbed(:exchange_rate,
          departure_date: departure_date,
          currency: 'usd',
          rate: 1.1138
        )

        allow(ExchangeRate).to receive(:for_departure_date_and_currency)
          .and_return(@exchange_rate)
      end

      it 'handles rounding for very small amounts' do
        money = Money.new(1, 'USD') # $0.01

        result = converter.convert_to_eur(money, departure_date)

        expect(result.cents).to eq(1) # Should round to €0.01
      end
    end

    context 'with persisted exchange rate in database' do
      before do
        create(:exchange_rate,
          departure_date: Date.parse('2022-01-30'),
          currency: 'usd',
          rate: 1.1138
        )
      end

      it 'works end-to-end with real database calls' do
        money = Money.new(111380, 'USD')

        result = converter.convert_to_eur(money, Date.parse('2022-01-30'))

        expect(result.currency.to_s).to eq('EUR')
        expect(result.cents).to eq(100000)
      end
    end
  end
end
