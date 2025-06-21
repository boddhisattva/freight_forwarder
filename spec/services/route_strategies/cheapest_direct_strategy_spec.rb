require 'rails_helper'

RSpec.describe RouteStrategies::CheapestDirectStrategy, type: :service do
  subject(:strategy) { described_class.new(repository, currency_converter: currency_converter) }

  let(:repository) { instance_double('DataRepository') }
  let(:currency_converter) { instance_double('CurrencyConverter') }

  describe '#find_route' do
    let(:origin) { 'CNSHA' }
    let(:destination) { 'NLRTM' }

    context 'when direct sailings exist' do
      before do
        @sailing1 = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          departure_date: Date.parse('2022-02-01'),
          arrival_date: Date.parse('2022-03-01'),
          sailing_code: 'ABCD'
        )

        @sailing2 = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          departure_date: Date.parse('2022-01-29'),
          arrival_date: Date.parse('2022-02-15'),
          sailing_code: 'QRST'
        )

        @rate1 = build_stubbed(:rate,
          sailing: @sailing1,
          amount_cents: 58930,
          currency: 'USD'
        )

        @rate2 = build_stubbed(:rate,
          sailing: @sailing2,
          amount_cents: 76196,
          currency: 'EUR'
        )

        allow(@sailing1).to receive(:rate).and_return(@rate1)
        allow(@sailing2).to receive(:rate).and_return(@rate2)

        # Mock currency converter responses
        allow(currency_converter).to receive(:convert_to_eur)
          .with(@rate1.amount, @sailing1.departure_date)
          .and_return(Money.new(52300, 'EUR'))

        allow(currency_converter).to receive(:convert_to_eur)
          .with(@rate2.amount, @sailing2.departure_date)
          .and_return(Money.new(76196, 'EUR'))

        allow(repository).to receive(:find_direct_sailings)
          .with(origin, destination)
          .and_return([ @sailing1, @sailing2 ])
      end

      it 'returns the cheapest direct sailing' do
        result = strategy.find_route(origin, destination)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        cheapest_route = result.first
        expect(cheapest_route[:origin_port]).to eq(origin)
        expect(cheapest_route[:destination_port]).to eq(destination)
        expect(cheapest_route[:sailing_code]).to eq('ABCD')
        expect(cheapest_route[:rate]).to eq('589.30')
        expect(cheapest_route[:rate_currency]).to eq('USD')
      end

      it 'formats dates correctly' do
        result = strategy.find_route(origin, destination)

        route = result.first
        expect(route[:departure_date]).to eq('2022-02-01')
        expect(route[:arrival_date]).to eq('2022-03-01')
      end

      it 'formats money amount correctly' do
        result = strategy.find_route(origin, destination)

        route = result.first
        expect(route[:rate]).to match(/^\d+\.\d{2}$/)
      end
    end

    context 'when multiple sailings have same EUR cost' do
      before do
        @sailing1 = build_stubbed(:sailing,
          sailing_code: 'SAME1',
          departure_date: Date.parse('2022-02-01')
        )

        @sailing2 = build_stubbed(:sailing,
          sailing_code: 'SAME2',
          departure_date: Date.parse('2022-02-02')
        )

        @rate1 = build_stubbed(:rate, amount_cents: 50000, currency: 'EUR')
        @rate2 = build_stubbed(:rate, amount_cents: 50000, currency: 'EUR')

        allow(@sailing1).to receive(:rate).and_return(@rate1)
        allow(@sailing2).to receive(:rate).and_return(@rate2)

        allow(currency_converter).to receive(:convert_to_eur)
          .and_return(Money.new(50000, 'EUR'))

        allow(repository).to receive(:find_direct_sailings)
          .and_return([ @sailing1, @sailing2 ])
      end

      it 'returns one of the sailings consistently' do
        result = strategy.find_route(origin, destination)

        expect(result.length).to eq(1)
        expect([ 'SAME1', 'SAME2' ]).to include(result.first[:sailing_code])
      end
    end

    context 'when no direct sailings exist' do
      before do
        allow(repository).to receive(:find_direct_sailings)
          .with(origin, destination)
          .and_return([])
      end

      it 'returns empty array' do
        result = strategy.find_route(origin, destination)
        expect(result).to eq([])
      end
    end

    context 'when sailing has no rate' do
      before do
        @sailing_without_rate = build_stubbed(:sailing, sailing_code: 'NORATES')

        allow(@sailing_without_rate).to receive(:rate).and_return(nil)

        # Mock currency converter to return nil for sailings without rates
        allow(currency_converter).to receive(:convert_to_eur)
          .and_return(nil)

        allow(repository).to receive(:find_direct_sailings)
          .and_return([ @sailing_without_rate ])
      end

      it 'handles sailing without rate gracefully' do
        expect {
          strategy.find_route(origin, destination)
        }.not_to raise_error
      end

      it 'returns empty array when all sailings have no rates' do
        result = strategy.find_route(origin, destination)
        expect(result).to eq([])
      end
    end

    context 'with actual response.json data' do
      before do
        # Create sailings matching response.json
        @sailing_abcd = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.parse('2022-02-01'),
          arrival_date: Date.parse('2022-03-01'),
          sailing_code: 'ABCD'
        )

        @sailing_efgh = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.parse('2022-02-02'),
          arrival_date: Date.parse('2022-03-02'),
          sailing_code: 'EFGH'
        )

        @sailing_ijkl = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.parse('2022-01-31'),
          arrival_date: Date.parse('2022-02-28'),
          sailing_code: 'IJKL'
        )

        @sailing_mnop = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.parse('2022-01-30'),
          arrival_date: Date.parse('2022-03-05'),
          sailing_code: 'MNOP'
        )

        @sailing_qrst = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.parse('2022-01-29'),
          arrival_date: Date.parse('2022-02-15'),
          sailing_code: 'QRST'
        )

        # Create rates matching response.json
        @rate_abcd = build_stubbed(:rate, amount_cents: 58930, currency: 'USD')
        @rate_efgh = build_stubbed(:rate, amount_cents: 89032, currency: 'EUR')
        @rate_ijkl = build_stubbed(:rate, amount_cents: 9745300, currency: 'JPY')
        @rate_mnop = build_stubbed(:rate, amount_cents: 45678, currency: 'USD')
        @rate_qrst = build_stubbed(:rate, amount_cents: 76196, currency: 'EUR')

        # Create Money objects
        @money_abcd = Money.new(58930, 'USD')
        @money_efgh = Money.new(89032, 'EUR')
        @money_ijkl = Money.new(9745300, 'JPY')
        @money_mnop = Money.new(45678, 'USD')
        @money_qrst = Money.new(76196, 'EUR')

        # Mock rate.amount to return Money objects
        allow(@rate_abcd).to receive(:amount).and_return(@money_abcd)
        allow(@rate_efgh).to receive(:amount).and_return(@money_efgh)
        allow(@rate_ijkl).to receive(:amount).and_return(@money_ijkl)
        allow(@rate_mnop).to receive(:amount).and_return(@money_mnop)
        allow(@rate_qrst).to receive(:amount).and_return(@money_qrst)

        # Mock sailing.rate associations
        allow(@sailing_abcd).to receive(:rate).and_return(@rate_abcd)
        allow(@sailing_efgh).to receive(:rate).and_return(@rate_efgh)
        allow(@sailing_ijkl).to receive(:rate).and_return(@rate_ijkl)
        allow(@sailing_mnop).to receive(:rate).and_return(@rate_mnop)
        allow(@sailing_qrst).to receive(:rate).and_return(@rate_qrst)

        # Mock currency converter with calculated EUR amounts
        # ABCD: 589.30 USD at 1.126 = ~523.22 EUR
        allow(currency_converter).to receive(:convert_to_eur)
          .with(@money_abcd, @sailing_abcd.departure_date)
          .and_return(Money.new(52322, 'EUR'))

        # EFGH: 890.32 EUR = 890.32 EUR
        allow(currency_converter).to receive(:convert_to_eur)
          .with(@money_efgh, @sailing_efgh.departure_date)
          .and_return(Money.new(89032, 'EUR'))

        # IJKL: 97453 JPY at 131.2 = ~742.58 EUR
        allow(currency_converter).to receive(:convert_to_eur)
          .with(@money_ijkl, @sailing_ijkl.departure_date)
          .and_return(Money.new(74258, 'EUR'))

        # MNOP: 456.78 USD at 1.1138 = ~410.13 EUR (cheapest)
        allow(currency_converter).to receive(:convert_to_eur)
          .with(@money_mnop, @sailing_mnop.departure_date)
          .and_return(Money.new(41013, 'EUR'))

        # QRST: 761.96 EUR = 761.96 EUR
        allow(currency_converter).to receive(:convert_to_eur)
          .with(@money_qrst, @sailing_qrst.departure_date)
          .and_return(Money.new(76196, 'EUR'))

        allow(repository).to receive(:find_direct_sailings)
          .with('CNSHA', 'NLRTM')
          .and_return([ @sailing_abcd, @sailing_efgh, @sailing_ijkl, @sailing_mnop, @sailing_qrst ])
      end

      it 'returns MNOP as the cheapest direct sailing' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        expect(result.length).to eq(1)
        cheapest_route = result.first

        expect(cheapest_route[:origin_port]).to eq('CNSHA')
        expect(cheapest_route[:destination_port]).to eq('NLRTM')
        expect(cheapest_route[:departure_date]).to eq('2022-01-30')
        expect(cheapest_route[:arrival_date]).to eq('2022-03-05')
        expect(cheapest_route[:sailing_code]).to eq('MNOP')
        expect(cheapest_route[:rate]).to eq('456.78')
        expect(cheapest_route[:rate_currency]).to eq('USD')
      end
    end

    context 'with different currencies' do
      before do
        @usd_sailing = build_stubbed(:sailing, sailing_code: 'USD001')
        @eur_sailing = build_stubbed(:sailing, sailing_code: 'EUR001')
        @jpy_sailing = build_stubbed(:sailing, sailing_code: 'JPY001')

        @usd_rate = build_stubbed(:rate, amount_cents: 111380, currency: 'USD')
        @eur_rate = build_stubbed(:rate, amount_cents: 100000, currency: 'EUR')
        @jpy_rate = build_stubbed(:rate, amount_cents: 9745300, currency: 'JPY')

        allow(@usd_sailing).to receive(:rate).and_return(@usd_rate)
        allow(@eur_sailing).to receive(:rate).and_return(@eur_rate)
        allow(@jpy_sailing).to receive(:rate).and_return(@jpy_rate)

        # Mock converted EUR amounts (JPY is cheapest after conversion)
        allow(currency_converter).to receive(:convert_to_eur)
          .with(@usd_rate.amount, @usd_sailing.departure_date)
          .and_return(Money.new(100000, 'EUR'))

        allow(currency_converter).to receive(:convert_to_eur)
          .with(@eur_rate.amount, @eur_sailing.departure_date)
          .and_return(Money.new(100000, 'EUR'))

        allow(currency_converter).to receive(:convert_to_eur)
          .with(@jpy_rate.amount, @jpy_sailing.departure_date)
          .and_return(Money.new(74530, 'EUR'))

        allow(repository).to receive(:find_direct_sailings)
          .and_return([ @usd_sailing, @eur_sailing, @jpy_sailing ])
      end

      it 'compares rates after EUR conversion' do
        result = strategy.find_route(origin, destination)

        expect(result.first[:sailing_code]).to eq('JPY001')
        expect(result.first[:rate_currency]).to eq('JPY')
      end
    end
  end
end
