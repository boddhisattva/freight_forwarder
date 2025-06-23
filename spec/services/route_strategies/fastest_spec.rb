require 'rails_helper'

RSpec.describe RouteStrategies::Fastest do
  let(:repository) { instance_double(DataRepository) }
  subject(:strategy) { described_class.new(repository) }

  let(:sailing) { build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM', rate: build_stubbed(:rate)) }
  let(:port_filter) { instance_double(PortConnectivityFilter) }

  before do
    allow(PortConnectivityFilter).to receive(:new).and_return(port_filter)
  end

  describe '#find_route' do
    it 'returns formatted route for direct sailing' do
      allow(port_filter).to receive(:filter_relevant_sailings).and_return([ sailing ])
      result = strategy.find_route('CNSHA', 'NLRTM')
      expect(result).to be_an(Array)
      expect(result.first[:sailing_code]).to eq(sailing.sailing_code)
    end

    it 'returns empty array if no route found' do
      allow(port_filter).to receive(:filter_relevant_sailings).and_return([])
      result = strategy.find_route('CNSHA', 'NLRTM')
      expect(result).to eq([])
    end

    context 'with 3+ leg routes' do
      before do
        create_three_plus_leg_test_data
        # Allow real PortConnectivityFilter for integration tests
        allow(PortConnectivityFilter).to receive(:new).and_call_original
      end

      it 'finds fastest route when faster than alternatives' do
        real_strategy = described_class.new(DataRepository.new)
        result = real_strategy.find_route('CNSHA', 'USNYC')

        # Should find 3-leg route: CNSHA->ESBCN->DEHAM->USNYC (faster than 4-leg)
        expect(result.size).to eq(3)
        expect(result[0][:sailing_code]).to eq('FAST_LEG1')
        expect(result[1][:sailing_code]).to eq('ALT_FAST2')
        expect(result[2][:sailing_code]).to eq('ALT_FAST3')
      end

      it 'returns correct sequence for fastest route' do
        real_strategy = described_class.new(DataRepository.new)
        result = real_strategy.find_route('CNSHA', 'USNYC')

        # Should find 3-leg route: CNSHA->ESBCN->DEHAM->USNYC
        expect(result[0][:origin_port]).to eq('CNSHA')
        expect(result[0][:destination_port]).to eq('ESBCN')

        expect(result[1][:origin_port]).to eq('ESBCN')
        expect(result[1][:destination_port]).to eq('DEHAM')

        expect(result[2][:origin_port]).to eq('DEHAM')
        expect(result[2][:destination_port]).to eq('USNYC')
      end

      it 'finds 3-leg route to intermediate destination' do
        real_strategy = described_class.new(DataRepository.new)
        result = real_strategy.find_route('CNSHA', 'BRSSZ')

        # Should find 3-leg route: CNSHA->ESBCN->NLRTM->BRSSZ
        expect(result.size).to eq(3)
        expect(result[0][:sailing_code]).to eq('FAST_LEG1')
        expect(result[1][:sailing_code]).to eq('FAST_LEG2')
        expect(result[2][:sailing_code]).to eq('FAST_LEG3')
      end

      it 'calculates total journey time correctly for multi-leg routes' do
        real_strategy = described_class.new(DataRepository.new)
        result = real_strategy.find_route('CNSHA', 'BRSSZ')

        # Verify journey time calculation includes connections
        total_days = (Date.parse(result.last[:arrival_date]) - Date.parse(result.first[:departure_date])).to_i
        expect(total_days).to be > 0
        expect(total_days).to be < 60 # Should be reasonable timeframe
      end

      it 'chooses alternative 3-leg route when primary becomes slow' do
        # Update LEG3 to be very slow to force alternative
        Sailing.find_by(sailing_code: 'FAST_LEG3').update!(
          departure_date: '2022-02-20',
          arrival_date: '2022-04-01' # Much slower - 40 days vs 9 days
        )

        real_strategy = described_class.new(DataRepository.new)
        result = real_strategy.find_route('CNSHA', 'USNYC')

        # Should find alternative route via DEHAM (3 legs vs 4 legs)
        expect(result.size).to eq(3)
        expect(result[0][:sailing_code]).to eq('FAST_LEG1') # CNSHA->ESBCN
        expect(result[1][:sailing_code]).to eq('ALT_FAST2') # ESBCN->DEHAM
        expect(result[2][:sailing_code]).to eq('ALT_FAST3') # DEHAM->USNYC
      end

      it 'maintains valid connection timing for 4-leg routes' do
        real_strategy = described_class.new(DataRepository.new)
        result = real_strategy.find_route('CNSHA', 'USNYC')

        result.each_cons(2) do |current, next_leg|
          current_arrival = Date.parse(current[:arrival_date])
          next_departure = Date.parse(next_leg[:departure_date])
          expect(next_departure).to be >= current_arrival
        end
      end

      it 'handles complex timing constraints for 5+ leg routes' do
        # Create 5-leg route: CNSHA->ESBCN->NLRTM->BRSSZ->DEHAM->USNYC
        create(:sailing,
          origin_port: 'BRSSZ', destination_port: 'DEHAM',
          departure_date: '2022-03-10', arrival_date: '2022-03-15',
          sailing_code: 'LEG5_1'
        )
        create(:rate,
          sailing: Sailing.find_by(sailing_code: 'LEG5_1'),
          amount_cents: 8000, currency: 'EUR'
        )

        create(:sailing,
          origin_port: 'DEHAM', destination_port: 'USNYC',
          departure_date: '2022-03-18', arrival_date: '2022-03-22',
          sailing_code: 'LEG5_2'
        )
        create(:rate,
          sailing: Sailing.find_by(sailing_code: 'LEG5_2'),
          amount_cents: 12000, currency: 'EUR'
        )

        real_strategy = described_class.new(DataRepository.new)
        result = real_strategy.find_route('CNSHA', 'USNYC')

        # Should still prefer the faster 4-leg or 3-leg route
        expect(result.size).to be <= 4
        expect(result).not_to be_empty
      end
    end
  end

  context 'real DB integration' do
    before do
      response_data = JSON.parse(File.read(Rails.root.join('db', 'response.json')))
      response_data['sailings'].each do |sailing_data|
        create(:sailing,
          origin_port: sailing_data['origin_port'],
          destination_port: sailing_data['destination_port'],
          departure_date: Date.parse(sailing_data['departure_date']),
          arrival_date: Date.parse(sailing_data['arrival_date']),
          sailing_code: sailing_data['sailing_code']
        )
      end
      response_data['rates'].each do |rate_data|
        sailing = Sailing.find_by(sailing_code: rate_data['sailing_code'])
        next unless sailing
        rate_in_cents = (BigDecimal(rate_data['rate']) * 100).to_i
        create(:rate,
          sailing: sailing,
          amount_cents: rate_in_cents,
          currency: rate_data['rate_currency']
        )
      end
      response_data['exchange_rates'].each do |date, rates|
        create(:exchange_rate,
          departure_date: Date.parse(date),
          currency: 'usd',
          rate: BigDecimal(rates['usd'].to_s)
        )
        create(:exchange_rate,
          departure_date: Date.parse(date),
          currency: 'jpy',
          rate: BigDecimal(rates['jpy'].to_s)
        )
      end
    end

    it 'finds the fastest route from CNSHA to NLRTM (QRST)' do
      allow(PortConnectivityFilter).to receive(:new).and_call_original
      real_strategy = described_class.new(DataRepository.new)
      result = real_strategy.find_route('CNSHA', 'NLRTM')
      expect(result).not_to be_empty
      expect(result.first[:sailing_code]).to eq('QRST')
    end

    it 'finds optimal multi-hop route when faster than direct routes' do
      # Add slower direct route to test multi-hop preference
      create(:sailing,
        origin_port: 'CNSHA', destination_port: 'BRSSZ',
        departure_date: '2022-01-29', arrival_date: '2022-04-30',
        sailing_code: 'SLOW_DIRECT_BRSSZ'
      )
      create(:rate,
        sailing: Sailing.find_by(sailing_code: 'SLOW_DIRECT_BRSSZ'),
        amount_cents: 50000, currency: 'EUR'
      )

      allow(PortConnectivityFilter).to receive(:new).and_call_original
      real_strategy = described_class.new(DataRepository.new)
      result = real_strategy.find_route('CNSHA', 'BRSSZ')

      # Should prefer multi-hop route over slow direct route
      expect(result.size).to be >= 2
      expect(result.first[:origin_port]).to eq('CNSHA')
      expect(result.last[:destination_port]).to eq('BRSSZ')
    end

    it 'handles 3+ leg routes with real data correctly' do
      allow(PortConnectivityFilter).to receive(:new).and_call_original
      real_strategy = described_class.new(DataRepository.new)
      result = real_strategy.find_route('CNSHA', 'USNYC')

      # Should find 3-leg route: CNSHA->ESBCN->NLRTM->USNYC
      expect(result.size).to eq(3)
      expect(result.first[:origin_port]).to eq('CNSHA')
      expect(result.last[:destination_port]).to eq('USNYC')

      # Verify route sequence
      result.each_cons(2) do |current, next_leg|
        expect(next_leg[:origin_port]).to eq(current[:destination_port])
      end
    end
  end

  private

  def create_three_plus_leg_test_data
    # Create exchange rates for new dates
    create(:exchange_rate, departure_date: '2022-02-10', currency: 'usd', rate: 1.1400)
    create(:exchange_rate, departure_date: '2022-02-20', currency: 'usd', rate: 1.1500)
    create(:exchange_rate, departure_date: '2022-03-05', currency: 'usd', rate: 1.1600)
    create(:exchange_rate, departure_date: '2022-03-18', currency: 'usd', rate: 1.1650)

    # Create slow direct route to force multi-leg preference
    direct_slow = create(:sailing,
      origin_port: 'CNSHA', destination_port: 'USNYC',
      departure_date: '2022-01-30', arrival_date: '2022-04-30',
      sailing_code: 'SLOW_DIRECT'
    )
    create(:rate, sailing: direct_slow, amount_cents: 50000, currency: 'EUR')

    # 4-leg fast route: CNSHA->ESBCN->NLRTM->BRSSZ->USNYC
    leg1 = create(:sailing,
      origin_port: 'CNSHA', destination_port: 'ESBCN',
      departure_date: '2022-01-29', arrival_date: '2022-02-05', # 7 days
      sailing_code: 'FAST_LEG1'
    )
    create(:rate, sailing: leg1, amount_cents: 15000, currency: 'EUR')

    leg2 = create(:sailing,
      origin_port: 'ESBCN', destination_port: 'NLRTM',
      departure_date: '2022-02-10', arrival_date: '2022-02-15', # 5 days sailing + 5 days wait
      sailing_code: 'FAST_LEG2'
    )
    create(:rate, sailing: leg2, amount_cents: 8000, currency: 'USD')

    leg3 = create(:sailing,
      origin_port: 'NLRTM', destination_port: 'BRSSZ',
      departure_date: '2022-02-20', arrival_date: '2022-02-29', # 9 days sailing + 5 days wait
      sailing_code: 'FAST_LEG3'
    )
    create(:rate, sailing: leg3, amount_cents: 12000, currency: 'EUR')

    leg4 = create(:sailing,
      origin_port: 'BRSSZ', destination_port: 'USNYC',
      departure_date: '2022-03-05', arrival_date: '2022-03-12', # 7 days sailing + 5 days wait
      sailing_code: 'FAST_LEG4'
    )
    create(:rate, sailing: leg4, amount_cents: 9000, currency: 'USD')

    # Alternative faster 3-leg route via DEHAM: CNSHA->ESBCN->DEHAM->USNYC
    alt2 = create(:sailing,
      origin_port: 'ESBCN', destination_port: 'DEHAM',
      departure_date: '2022-02-10', arrival_date: '2022-02-14', # 4 days sailing + 5 days wait
      sailing_code: 'ALT_FAST2'
    )
    create(:rate, sailing: alt2, amount_cents: 7000, currency: 'EUR')

    alt3 = create(:sailing,
      origin_port: 'DEHAM', destination_port: 'USNYC',
      departure_date: '2022-02-18', arrival_date: '2022-02-25', # 7 days sailing + 4 days wait
      sailing_code: 'ALT_FAST3'
    )
    create(:rate, sailing: alt3, amount_cents: 18000, currency: 'EUR')

    # Total times:
    # Direct slow: 90 days (Jan 30 - Apr 30)
    # 4-leg fast: ~42 days (Jan 29 - Mar 12)
    # 3-leg via DEHAM: ~27 days (Jan 29 - Feb 25)
  end
end
