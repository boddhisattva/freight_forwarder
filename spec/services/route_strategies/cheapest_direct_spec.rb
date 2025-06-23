require 'rails_helper'

RSpec.describe RouteStrategies::CheapestDirect, type: :service do
  subject(:strategy) { described_class.new(repository, currency_converter: currency_converter) }

  let(:repository) { instance_double('DataRepository') }
  let(:currency_converter) { instance_double('CurrencyConverter') }

  describe '#find_route' do
    let(:origin) { 'CNSHA' }
    let(:destination) { 'NLRTM' }

    context 'successful route finding' do
      before do
        @usd_sailing = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          departure_date: Date.parse('2022-02-01'),
          sailing_code: 'USD001'
        )

        @eur_sailing = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          departure_date: Date.parse('2022-01-29'),
          sailing_code: 'EUR001'
        )

        @jpy_sailing = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          departure_date: Date.parse('2022-01-31'),
          sailing_code: 'JPY001'
        )

        @sailing_without_rate = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          sailing_code: 'NORATES'
        )

        allow(repository).to receive(:find_direct_sailings)
          .with(origin, destination)
          .and_return([ @usd_sailing, @eur_sailing, @jpy_sailing, @sailing_without_rate ])

        # JPY is cheapest after conversion
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@usd_sailing)
          .and_return(Money.new(100000, 'EUR'))

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@eur_sailing)
          .and_return(Money.new(90000, 'EUR'))

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@jpy_sailing)
          .and_return(Money.new(75000, 'EUR'))

        # Sailing without rate returns nil
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_without_rate)
          .and_return(nil)

        allow(strategy).to receive(:format_route)
          .with([ @jpy_sailing ])
          .and_return([ {
            origin_port: origin,
            destination_port: destination,
            departure_date: '2022-01-31',
            arrival_date: '2022-02-28',
            sailing_code: 'JPY001',
            rate: '97453',
            rate_currency: 'JPY'
          } ])
      end

      it 'returns cheapest direct sailing after currency conversion' do
        result = strategy.find_route(origin, destination)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        cheapest_route = result.first
        expect(cheapest_route[:sailing_code]).to eq('JPY001')
        expect(cheapest_route[:rate_currency]).to eq('JPY')
      end

      it 'ignores sailings without valid rates' do
        result = strategy.find_route(origin, destination)

        sailing_codes = result.map { |route| route[:sailing_code] }
        expect(sailing_codes).not_to include('NORATES')
      end
    end

    context 'with minimal real data' do
      before do
        # Create only the sailings needed for CNSHA->NLRTM direct route test
        @sailing_abcd = create(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.parse('2022-02-01'),
          arrival_date: Date.parse('2022-03-01'),
          sailing_code: 'ABCD'
        )

        @sailing_mnop = create(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.parse('2022-01-30'),
          arrival_date: Date.parse('2022-03-05'),
          sailing_code: 'MNOP'
        )

        @sailing_qrst = create(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.parse('2022-01-29'),
          arrival_date: Date.parse('2022-02-15'),
          sailing_code: 'QRST'
        )

        # Create rates for the sailings
        create(:rate,
          sailing: @sailing_abcd,
          amount_cents: 58930, # 589.30 USD
          currency: 'USD'
        )

        create(:rate,
          sailing: @sailing_mnop,
          amount_cents: 45678, # 456.78 USD
          currency: 'USD'
        )

        create(:rate,
          sailing: @sailing_qrst,
          amount_cents: 76196, # 761.96 EUR
          currency: 'EUR'
        )

        # Create only the exchange rates needed for the test dates
        create(:exchange_rate,
          departure_date: Date.parse('2022-01-29'),
          currency: 'usd',
          rate: 1.1138
        )

        create(:exchange_rate,
          departure_date: Date.parse('2022-01-30'),
          currency: 'usd',
          rate: 1.1138
        )

        create(:exchange_rate,
          departure_date: Date.parse('2022-02-01'),
          currency: 'usd',
          rate: 1.126
        )

        # Use real repository and currency converter
        @real_repository = DataRepository.new
        @real_currency_converter = CurrencyConverter.new
        @real_strategy = described_class.new(@real_repository, currency_converter: @real_currency_converter)
      end

      it 'returns MNOP as cheapest direct sailing from minimal test data' do
        result = @real_strategy.find_route('CNSHA', 'NLRTM')

        expect(result.length).to eq(1)
        cheapest_route = result.first

        expect(cheapest_route[:sailing_code]).to eq('MNOP')
        expect(cheapest_route[:rate]).to eq('456.78')
        expect(cheapest_route[:rate_currency]).to eq('USD')
      end

      it 'handles currency conversion correctly with real data' do
        result = @real_strategy.find_route('CNSHA', 'NLRTM')

        # Verify that currency conversion is working
        # MNOP should be cheapest: 456.78 USD / 1.1138 = ~410.11 EUR
        # QRST: 761.96 EUR (direct)
        # ABCD: 589.30 USD / 1.126 = ~523.36 EUR
        expect(result.first[:sailing_code]).to eq('MNOP')
      end
    end

    context 'error handling scenarios' do
      it 'returns structured error when no direct sailings exist' do
        allow(repository).to receive(:find_direct_sailings)
          .with(origin, destination)
          .and_return([])

        result = strategy.find_route(origin, destination)

        expect(result).to eq({
          error: "No direct sailings found between #{origin} and #{destination}",
          error_code: "NO_DIRECT_SAILINGS"
        })
      end

      it 'returns structured error when all sailings have invalid rates' do
        sailing_without_rate = build_stubbed(:sailing, sailing_code: 'INVALID')

        allow(repository).to receive(:find_direct_sailings)
          .with(origin, destination)
          .and_return([ sailing_without_rate ])

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(sailing_without_rate)
          .and_return(nil)

        result = strategy.find_route(origin, destination)

        expect(result).to eq({
          error: "No sailings with valid rates found between #{origin} and #{destination}",
          error_code: "NO_VALID_RATES"
        })
      end
    end
  end
end
