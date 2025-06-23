require 'rails_helper'

RSpec.describe RouteStrategies::CheapestDirect, type: :service do
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

        allow(repository).to receive(:find_direct_sailings)
          .with(origin, destination)
          .and_return([ @sailing1, @sailing2 ])

        # Mock convert_rate_to_eur method
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing1)
          .and_return(Money.new(52300, 'EUR'))

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing2)
          .and_return(Money.new(76196, 'EUR'))

        # Mock format_route method
        allow(strategy).to receive(:format_route)
          .with([ @sailing1 ])
          .and_return([ {
            origin_port: origin,
            destination_port: destination,
            departure_date: '2022-02-01',
            arrival_date: '2022-03-01',
            sailing_code: 'ABCD',
            rate: '589.30',
            rate_currency: 'USD'
          } ])
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

        allow(repository).to receive(:find_direct_sailings)
          .and_return([ @sailing1, @sailing2 ])

        allow(strategy).to receive(:convert_rate_to_eur)
          .and_return(Money.new(50000, 'EUR'))

        allow(strategy).to receive(:format_route)
          .and_return([ { sailing_code: 'SAME1' } ])
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

      it 'returns error object instead of empty array' do
        result = strategy.find_route(origin, destination)

        expect(result).to be_a(Hash)
        expect(result[:error]).to eq("No direct sailings found between #{origin} and #{destination}")
        expect(result[:error_code]).to eq("NO_DIRECT_SAILINGS")
      end
    end

    context 'when sailing has no rate' do
      before do
        @sailing_without_rate = build_stubbed(:sailing, sailing_code: 'NORATES')

        allow(repository).to receive(:find_direct_sailings)
          .and_return([ @sailing_without_rate ])

        # Mock convert_rate_to_eur to return nil for sailings without rates
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_without_rate)
          .and_return(nil)
      end

      it 'handles sailing without rate gracefully' do
        expect {
          strategy.find_route(origin, destination)
        }.not_to raise_error
      end

      it 'returns error object when all sailings have no rates' do
        result = strategy.find_route(origin, destination)

        expect(result).to be_a(Hash)
        expect(result[:error]).to eq("No sailings with valid rates found between #{origin} and #{destination}")
        expect(result[:error_code]).to eq("NO_VALID_RATES")
      end
    end

    # NEW TEST CONTEXT FOR Float::INFINITY SCENARIO
    context 'when mixing sailings with and without rates (Float::INFINITY scenario)' do
      before do
        # Sailing with a good rate
        @sailing_with_rate = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          departure_date: Date.parse('2022-02-01'),
          arrival_date: Date.parse('2022-03-01'),
          sailing_code: 'HASRATE'
        )

        # Sailing without rate (will get Float::INFINITY)
        @sailing_without_rate = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          departure_date: Date.parse('2022-01-29'),
          arrival_date: Date.parse('2022-02-15'),
          sailing_code: 'NORATES'
        )

        # Another sailing without rate
        @another_sailing_without_rate = build_stubbed(:sailing,
          origin_port: origin,
          destination_port: destination,
          departure_date: Date.parse('2022-02-02'),
          arrival_date: Date.parse('2022-03-02'),
          sailing_code: 'ALSONORATES'
        )

        allow(repository).to receive(:find_direct_sailings)
          .with(origin, destination)
          .and_return([ @sailing_with_rate, @sailing_without_rate, @another_sailing_without_rate ])

        # Mock convert_rate_to_eur method
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_with_rate)
          .and_return(Money.new(52300, 'EUR'))

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_without_rate)
          .and_return(nil)

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@another_sailing_without_rate)
          .and_return(nil)

        # Mock format_route method
        allow(strategy).to receive(:format_route)
          .with([ @sailing_with_rate ])
          .and_return([ {
            origin_port: origin,
            destination_port: destination,
            departure_date: '2022-02-01',
            arrival_date: '2022-03-01',
            sailing_code: 'HASRATE',
            rate: '589.30',
            rate_currency: 'USD'
          } ])
      end

      it 'ignores sailings without rates due to Float::INFINITY and picks the valid one' do
        result = strategy.find_route(origin, destination)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        selected_route = result.first
        expect(selected_route[:sailing_code]).to eq('HASRATE')
        expect(selected_route[:rate]).to eq('589.30')
        expect(selected_route[:rate_currency]).to eq('USD')
      end

      it 'demonstrates Float::INFINITY behavior prevents selection of nil rates' do
        # This test shows that sailings without rates get Float::INFINITY
        # and are therefore never selected as the minimum
        result = strategy.find_route(origin, destination)

        # The result should never contain sailings without rates
        expect(result.first[:sailing_code]).not_to eq('NORATES')
        expect(result.first[:sailing_code]).not_to eq('ALSONORATES')
        expect(result.first[:sailing_code]).to eq('HASRATE')
      end

      it 'handles edge case where expensive valid rate is still better than Float::INFINITY' do
        # Even a very expensive rate should beat Float::INFINITY
        very_expensive_sailing = build_stubbed(:sailing, sailing_code: 'EXPENSIVE')

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(very_expensive_sailing)
          .and_return(Money.new(999999999, 'EUR'))

        allow(repository).to receive(:find_direct_sailings)
          .and_return([ very_expensive_sailing, @sailing_without_rate ])

        allow(strategy).to receive(:format_route)
          .with([ very_expensive_sailing ])
          .and_return([ { sailing_code: 'EXPENSIVE' } ])

        result = strategy.find_route(origin, destination)

        # Should pick the expensive one over the one with no rate (Float::INFINITY)
        expect(result.first[:sailing_code]).to eq('EXPENSIVE')
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

        allow(repository).to receive(:find_direct_sailings)
          .with('CNSHA', 'NLRTM')
          .and_return([ @sailing_abcd, @sailing_efgh, @sailing_ijkl, @sailing_mnop, @sailing_qrst ])

        # Mock convert_rate_to_eur with calculated EUR amounts
        # ABCD: 589.30 USD at 1.126 = ~523.22 EUR
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_abcd)
          .and_return(Money.new(52322, 'EUR'))

        # EFGH: 890.32 EUR = 890.32 EUR
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_efgh)
          .and_return(Money.new(89032, 'EUR'))

        # IJKL: 97453 JPY at 131.2 = ~742.58 EUR
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_ijkl)
          .and_return(Money.new(74258, 'EUR'))

        # MNOP: 456.78 USD at 1.1138 = ~410.13 EUR (cheapest)
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_mnop)
          .and_return(Money.new(41013, 'EUR'))

        # QRST: 761.96 EUR = 761.96 EUR
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@sailing_qrst)
          .and_return(Money.new(76196, 'EUR'))

        # Mock format_route method
        allow(strategy).to receive(:format_route)
          .with([ @sailing_mnop ])
          .and_return([ {
            origin_port: 'CNSHA',
            destination_port: 'NLRTM',
            departure_date: '2022-01-30',
            arrival_date: '2022-03-05',
            sailing_code: 'MNOP',
            rate: '456.78',
            rate_currency: 'USD'
          } ])
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

        allow(repository).to receive(:find_direct_sailings)
          .and_return([ @usd_sailing, @eur_sailing, @jpy_sailing ])

        # Mock converted EUR amounts (JPY is cheapest after conversion)
        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@usd_sailing)
          .and_return(Money.new(100000, 'EUR'))

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@eur_sailing)
          .and_return(Money.new(100000, 'EUR'))

        allow(strategy).to receive(:convert_rate_to_eur)
          .with(@jpy_sailing)
          .and_return(Money.new(74530, 'EUR'))

        allow(strategy).to receive(:format_route)
          .with([ @jpy_sailing ])
          .and_return([ { sailing_code: 'JPY001', rate_currency: 'JPY' } ])
      end

      it 'compares rates after EUR conversion' do
        result = strategy.find_route(origin, destination)

        expect(result.first[:sailing_code]).to eq('JPY001')
        expect(result.first[:rate_currency]).to eq('JPY')
      end
    end

    context 'error handling scenarios' do
      it 'returns structured error when no direct sailings exist' do
        allow(repository).to receive(:find_direct_sailings).and_return([])

        result = strategy.find_route(origin, destination)

        expect(result).to eq({
          error: "No direct sailings found between #{origin} and #{destination}",
          error_code: "NO_DIRECT_SAILINGS"
        })
      end

      it 'returns structured error when cheapest sailing has no valid rate' do
        sailing = build_stubbed(:sailing, sailing_code: 'INVALID')

        allow(repository).to receive(:find_direct_sailings).and_return([ sailing ])
        allow(strategy).to receive(:convert_rate_to_eur).and_return(nil)

        result = strategy.find_route(origin, destination)

        expect(result).to eq({
          error: "No sailings with valid rates found between #{origin} and #{destination}",
          error_code: "NO_VALID_RATES"
        })
      end
    end
  end
end
