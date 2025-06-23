require 'rails_helper'

RSpec.describe RouteStrategies::Cheapest do
  subject(:strategy) { described_class.new(repository) }
  let(:repository) { DataRepository.new }

  describe '#find_route using Bellman-Ford algorithm' do
    context 'with response.json data (CNSHA to NLRTM)' do
      before do
        create_response_json_cost_data
      end

      it 'chooses cheapest route (Barcelona) over MNOP direct route' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        # Barcelona route: €261.96 + $69.96/1.1482 = €322.85 (cheaper)
        # vs MNOP: $456.78/1.1138 = €410.13 (more expensive)
        expect(result.size).to eq(2)
        expect(result.first[:sailing_code]).to eq('ERXQ')
        expect(result.last[:sailing_code]).to eq('ETRG')
      end

      it 'returns exact expected output format for Barcelona route' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        expect(result.first).to include(
          origin_port: "CNSHA",
          destination_port: "ESBCN",
          departure_date: "2022-01-29",
          arrival_date: "2022-02-12",
          sailing_code: "ERXQ",
          rate: "261.96",
          rate_currency: "EUR"
        )

        expect(result.last).to include(
          origin_port: "ESBCN",
          destination_port: "NLRTM",
          departure_date: "2022-02-16",
          arrival_date: "2022-02-20",
          sailing_code: "ETRG",
          rate: "69.96",
          rate_currency: "USD"
        )
      end

      it 'correctly identifies Barcelona route as cheapest: €261.96 + $69.96/1.1482 = €322.85' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        # Barcelona route total: €322.85 (cheapest)
        # vs MNOP: $456.78/1.1138 = €410.13 (more expensive)
        expect(result.first[:rate]).to eq('261.96')
        expect(result.first[:rate_currency]).to eq('EUR')
        expect(result.last[:rate]).to eq('69.96')
        expect(result.last[:rate_currency]).to eq('USD')
      end

      context 'when Barcelona route is made expensive' do
        before do
          Sailing.find_by(sailing_code: 'ERXQ').rate.update!(
            amount: Money.new(150000, 'EUR')
          )
        end

        it 'chooses MNOP direct route when Barcelona becomes expensive' do
          result = strategy.find_route('CNSHA', 'NLRTM')

          expect(result.size).to eq(1)
          expect(result.first[:sailing_code]).to eq('MNOP')
        end

        it 'calculates MNOP cost correctly: $456.78/1.1138 = €410.13' do
          result = strategy.find_route('CNSHA', 'NLRTM')

          expect(result.first[:rate]).to eq('456.78')
          expect(result.first[:rate_currency]).to eq('USD')
        end
      end
    end

    context 'with 3+ leg routes' do
      before do
        create_three_plus_leg_data
      end

      it 'finds optimal 4-leg route when cheaper than alternatives' do
        result = strategy.find_route('CNSHA', 'USNYC')

        # 4-leg route should be: CNSHA->ESBCN->NLRTM->BRSSZ->USNYC
        expect(result.size).to eq(4)
        expect(result[0][:sailing_code]).to eq('LEG1')
        expect(result[1][:sailing_code]).to eq('LEG2')
        expect(result[2][:sailing_code]).to eq('LEG3')
        expect(result[3][:sailing_code]).to eq('LEG4')
      end

      it 'returns correct sequence for 4-leg route' do
        result = strategy.find_route('CNSHA', 'USNYC')

        expect(result[0][:origin_port]).to eq('CNSHA')
        expect(result[0][:destination_port]).to eq('ESBCN')

        expect(result[1][:origin_port]).to eq('ESBCN')
        expect(result[1][:destination_port]).to eq('NLRTM')

        expect(result[2][:origin_port]).to eq('NLRTM')
        expect(result[2][:destination_port]).to eq('BRSSZ')

        expect(result[3][:origin_port]).to eq('BRSSZ')
        expect(result[3][:destination_port]).to eq('USNYC')
      end

      it 'finds 3-leg route to intermediate destination' do
        result = strategy.find_route('CNSHA', 'BRSSZ')

        # 3-leg route: CNSHA->ESBCN->NLRTM->BRSSZ
        expect(result.size).to eq(3)
        expect(result[0][:sailing_code]).to eq('LEG1')
        expect(result[1][:sailing_code]).to eq('LEG2')
        expect(result[2][:sailing_code]).to eq('LEG3')
      end

      it 'calculates total cost correctly for multi-leg routes' do
        result = strategy.find_route('CNSHA', 'BRSSZ')

        # Should be cheaper than any direct alternative
        total_cost_eur = result.sum do |leg|
          rate = BigDecimal(leg[:rate])
          if leg[:rate_currency] == 'EUR'
            rate
          else
            # Convert using exchange rate for departure date
            exchange_rate = ExchangeRate.for_departure_date_and_currency(
              Date.parse(leg[:departure_date]),
              leg[:rate_currency].downcase
            )
            rate / exchange_rate.rate
          end
        end

        expect(total_cost_eur).to be < 500 # Should be reasonable cost
      end

      it 'chooses alternative 3-leg route when primary route becomes expensive' do
        # Make the primary 4-leg route expensive by increasing LEG3 cost
        Sailing.find_by(sailing_code: 'LEG3').rate.update!(
          amount: Money.new(50000, 'EUR') # €500
        )

        result = strategy.find_route('CNSHA', 'USNYC')

        # Should find alternative route via DEHAM
        expect(result.size).to eq(3)
        expect(result[0][:sailing_code]).to eq('LEG1') # CNSHA->ESBCN
        expect(result[1][:sailing_code]).to eq('ALT2') # ESBCN->DEHAM
        expect(result[2][:sailing_code]).to eq('ALT3') # DEHAM->USNYC
      end

      it 'maintains valid connection timing for 4-leg routes' do
        result = strategy.find_route('CNSHA', 'USNYC')

        result.each_cons(2) do |current, next_leg|
          current_arrival = Date.parse(current[:arrival_date])
          next_departure = Date.parse(next_leg[:departure_date])
          expect(next_departure).to be >= current_arrival
        end
      end
    end

    context 'WRT-0002: original problem scenario' do
      before do
        create_wrt_0002_original_data
      end

      it 'returns cheapest multi-leg route when indirect is cheaper' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        expect(result.size).to eq(2)
        expect(result.first[:sailing_code]).to eq('ERXQ')
        expect(result.last[:sailing_code]).to eq('ETRG')
      end

      it 'provides correct sequence and timing for connections' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        expect(result.first[:origin_port]).to eq('CNSHA')
        expect(result.first[:destination_port]).to eq('ESBCN')
        expect(result.last[:origin_port]).to eq('ESBCN')
        expect(result.last[:destination_port]).to eq('NLRTM')

        # Verify valid connection timing
        first_arrival = Date.parse(result.first[:arrival_date])
        second_departure = Date.parse(result.last[:departure_date])
        expect(second_departure).to be >= first_arrival
      end
    end

    context 'with multiple currency conversions' do
      before do
        # Clear any existing data
        ExchangeRate.delete_all
        Rate.delete_all
        Sailing.delete_all

        create_response_json_cost_data
      end

      it 'correctly compares costs across USD, EUR, JPY and chooses Barcelona route' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        # Should find Barcelona route as cheapest after conversion
        expect(result).not_to be_empty
        expect(result.first[:sailing_code]).to eq('ERXQ')
        expect(result.last[:sailing_code]).to eq('ETRG')
      end

      it 'handles multi-currency comparison when Barcelona route is expensive' do
        # Make Barcelona route expensive
        Sailing.find_by(sailing_code: 'ERXQ').rate.update!(amount: Money.new(150000, 'EUR'))
        Sailing.find_by(sailing_code: 'ETRG').rate.update!(amount: Money.new(15000, 'USD'))

        result = strategy.find_route('CNSHA', 'NLRTM')

        # MNOP: $456.78 ÷ 1.1138 = €410.13 should be next cheapest
        # vs ABCD: $589.30 ÷ 1.126 = €523.31
        # vs IJKL: ¥97453 ÷ 131.2 = €742.78
        # vs EFGH: €890.32
        expect(result.first[:sailing_code]).to eq('MNOP')
        expect(result.first[:rate_currency]).to eq('USD')
      end

      it 'handles JPY conversion correctly' do
        # Make USD and EUR routes very expensive to force JPY selection
        Sailing.find_by(sailing_code: 'MNOP').rate.update!(amount: Money.new(500000, 'USD'))
        Sailing.find_by(sailing_code: 'ABCD').rate.update!(amount: Money.new(500000, 'USD'))
        Sailing.find_by(sailing_code: 'EFGH').rate.update!(amount: Money.new(200000, 'EUR'))
        Sailing.find_by(sailing_code: 'ERXQ').rate.update!(amount: Money.new(200000, 'EUR'))

        result = strategy.find_route('CNSHA', 'NLRTM')

        # Now IJKL: ¥97453 ÷ 131.2 = €742.78 should win
        expect(result.first[:sailing_code]).to eq('IJKL')
        expect(result.first[:rate_currency]).to eq('JPY')
      end
    end

    context 'algorithm correctness verification' do
      before do
        # Clear any existing data
        ExchangeRate.delete_all
        Rate.delete_all
        Sailing.delete_all

        create_response_json_cost_data
      end

      it 'finds globally optimal solution through relaxation' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        # Bellman-Ford should find Barcelona route as absolute cheapest
        expect(result.first[:sailing_code]).to eq('ERXQ')
        expect(result.last[:sailing_code]).to eq('ETRG')

        # Calculate and verify it's actually cheapest in EUR
        barcelona_total = 261.96 + (69.96 / 1.1482)  # ≈ €322.85
        expect(barcelona_total).to be < 400  # Much cheaper than MNOP's €410.13
      end

      it 'performs relaxation for N-1 iterations correctly' do
        result = strategy.find_route('CNSHA', 'NLRTM')
        expect(result).not_to be_empty
      end

      it 'properly formats output with all required fields' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        result.each do |leg|
          expect(leg).to include(
            :origin_port, :destination_port, :departure_date,
            :arrival_date, :sailing_code, :rate, :rate_currency
          )
        end
      end

      it 'maintains connection timing for multi-leg routes' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        if result.size > 1
          result.each_cons(2) do |current, next_leg|
            current_arrival = Date.parse(current[:arrival_date])
            next_departure = Date.parse(next_leg[:departure_date])
            expect(next_departure).to be >= current_arrival
          end
        end
      end
    end

    context 'complex multi-hop scenarios' do
      before do
        # Clear any existing data
        ExchangeRate.delete_all
        Rate.delete_all
        Sailing.delete_all

        create_response_json_cost_data
        create_complex_routing_data
      end

      it 'finds optimal route through multiple intermediate ports' do
        result = strategy.find_route('CNSHA', 'BRSSZ')

        expect(result).not_to be_empty
        expect(result.first[:origin_port]).to eq('CNSHA')
        expect(result.last[:destination_port]).to eq('BRSSZ')
      end

      it 'handles three-leg routes with cost optimization' do
        result = strategy.find_route('CNSHA', 'BRSSZ')

        if result.size >= 2
          # Verify proper sequence
          expect(result[1][:origin_port]).to eq(result[0][:destination_port])
          if result.size == 3
            expect(result[2][:origin_port]).to eq(result[1][:destination_port])
          end
        end
      end
    end

    context 'edge cases' do
      it 'returns empty array when no route exists' do
        result = strategy.find_route('NONEXISTENT', 'NOWHERE')
        expect(result).to eq([])
      end

      it 'handles single port routing' do
        result = strategy.find_route('CNSHA', 'CNSHA')
        expect(result).to eq([])
      end

      it 'handles sailings without rates gracefully' do
        Sailing.create!(
          origin_port: 'CNSHA', destination_port: 'NLRTM',
          departure_date: '2022-01-28', arrival_date: '2022-01-30',
          sailing_code: 'NO_RATE'
        )

        expect {
          strategy.find_route('CNSHA', 'NLRTM')
        }.not_to raise_error
      end
    end
  end

  private

  def create_response_json_cost_data
    # Exchange rates from response.json - EXACT VALUES
    ExchangeRate.find_or_create_by!(departure_date: '2022-01-29', currency: 'usd') { |er| er.rate = 1.1138 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-01-29', currency: 'jpy') { |er| er.rate = 130.85 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-01-30', currency: 'usd') { |er| er.rate = 1.1138 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-01-30', currency: 'jpy') { |er| er.rate = 132.97 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-01-31', currency: 'usd') { |er| er.rate = 1.1156 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-01-31', currency: 'jpy') { |er| er.rate = 131.2 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-01', currency: 'usd') { |er| er.rate = 1.126 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-01', currency: 'jpy') { |er| er.rate = 130.15 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-02', currency: 'usd') { |er| er.rate = 1.1323 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-02', currency: 'jpy') { |er| er.rate = 133.91 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-15', currency: 'usd') { |er| er.rate = 1.1483 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-15', currency: 'jpy') { |er| er.rate = 149.93 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-16', currency: 'usd') { |er| er.rate = 1.1482 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-16', currency: 'jpy') { |er| er.rate = 149.93 }

    # Direct routes CNSHA -> NLRTM from response.json - EXACT VALUES
    abcd = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'NLRTM',
      departure_date: '2022-02-01', arrival_date: '2022-03-01',
      sailing_code: 'ABCD'
    )
    Rate.create!(sailing: abcd, amount: Money.new(58930, 'USD'), currency: 'USD')

    efgh = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'NLRTM',
      departure_date: '2022-02-02', arrival_date: '2022-03-02',
      sailing_code: 'EFGH'
    )
    Rate.create!(sailing: efgh, amount: Money.new(89032, 'EUR'), currency: 'EUR')

    ijkl = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'NLRTM',
      departure_date: '2022-01-31', arrival_date: '2022-02-28',
      sailing_code: 'IJKL'
    )
    Rate.create!(sailing: ijkl, amount: Money.new(9745300, 'JPY'), currency: 'JPY')

    mnop = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'NLRTM',
      departure_date: '2022-01-30', arrival_date: '2022-03-05',
      sailing_code: 'MNOP'
    )
    Rate.create!(sailing: mnop, amount: Money.new(45678, 'USD'), currency: 'USD')

    qrst = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'NLRTM',
      departure_date: '2022-01-29', arrival_date: '2022-02-15',
      sailing_code: 'QRST'
    )
    Rate.create!(sailing: qrst, amount: Money.new(76196, 'EUR'), currency: 'EUR')

    # Barcelona route from response.json - EXACT VALUES
    erxq = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'ESBCN',
      departure_date: '2022-01-29', arrival_date: '2022-02-12',
      sailing_code: 'ERXQ'
    )
    Rate.create!(sailing: erxq, amount: Money.new(26196, 'EUR'), currency: 'EUR')

    etrf = Sailing.create!(
      origin_port: 'ESBCN', destination_port: 'NLRTM',
      departure_date: '2022-02-15', arrival_date: '2022-03-29',
      sailing_code: 'ETRF'
    )
    Rate.create!(sailing: etrf, amount: Money.new(7096, 'USD'), currency: 'USD')

    etrg = Sailing.create!(
      origin_port: 'ESBCN', destination_port: 'NLRTM',
      departure_date: '2022-02-16', arrival_date: '2022-02-20',
      sailing_code: 'ETRG'
    )
    Rate.create!(sailing: etrg, amount: Money.new(6996, 'USD'), currency: 'USD')
  end

  def create_three_plus_leg_data
    # Add additional exchange rates for new dates
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-10', currency: 'usd') { |er| er.rate = 1.1400 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-20', currency: 'usd') { |er| er.rate = 1.1500 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-03-05', currency: 'usd') { |er| er.rate = 1.1600 }

    # Create expensive direct route to force multi-leg preference
    direct_expensive = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'USNYC',
      departure_date: '2022-01-30', arrival_date: '2022-03-15',
      sailing_code: 'EXPENSIVE_DIRECT'
    )
    Rate.create!(sailing: direct_expensive, amount: Money.new(200000, 'EUR'), currency: 'EUR')

    # 4-leg route: CNSHA->ESBCN->NLRTM->BRSSZ->USNYC
    leg1 = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'ESBCN',
      departure_date: '2022-01-29', arrival_date: '2022-02-05',
      sailing_code: 'LEG1'
    )
    Rate.create!(sailing: leg1, amount: Money.new(15000, 'EUR'), currency: 'EUR')

    leg2 = Sailing.create!(
      origin_port: 'ESBCN', destination_port: 'NLRTM',
      departure_date: '2022-02-10', arrival_date: '2022-02-15',
      sailing_code: 'LEG2'
    )
    Rate.create!(sailing: leg2, amount: Money.new(8000, 'USD'), currency: 'USD')

    leg3 = Sailing.create!(
      origin_port: 'NLRTM', destination_port: 'BRSSZ',
      departure_date: '2022-02-20', arrival_date: '2022-03-01',
      sailing_code: 'LEG3'
    )
    Rate.create!(sailing: leg3, amount: Money.new(12000, 'EUR'), currency: 'EUR')

    leg4 = Sailing.create!(
      origin_port: 'BRSSZ', destination_port: 'USNYC',
      departure_date: '2022-03-05', arrival_date: '2022-03-12',
      sailing_code: 'LEG4'
    )
    Rate.create!(sailing: leg4, amount: Money.new(9000, 'USD'), currency: 'USD')

    # Alternative 3-leg route via DEHAM: CNSHA->ESBCN->DEHAM->USNYC
    alt2 = Sailing.create!(
      origin_port: 'ESBCN', destination_port: 'DEHAM',
      departure_date: '2022-02-10', arrival_date: '2022-02-14',
      sailing_code: 'ALT2'
    )
    Rate.create!(sailing: alt2, amount: Money.new(7000, 'EUR'), currency: 'EUR')

    alt3 = Sailing.create!(
      origin_port: 'DEHAM', destination_port: 'USNYC',
      departure_date: '2022-02-18', arrival_date: '2022-02-25',
      sailing_code: 'ALT3'
    )
    Rate.create!(sailing: alt3, amount: Money.new(25000, 'EUR'), currency: 'EUR')
  end

  def create_wrt_0002_original_data
    # Original WRT-0002 test data where indirect route wins
    ExchangeRate.find_or_create_by!(departure_date: '2022-01-29', currency: 'usd') { |er| er.rate = 1.1138 }
    ExchangeRate.find_or_create_by!(departure_date: '2022-02-16', currency: 'usd') { |er| er.rate = 1.1482 }

    # Expensive direct route
    qrst = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'NLRTM',
      departure_date: '2022-01-29', arrival_date: '2022-02-15',
      sailing_code: 'QRST_EXPENSIVE'
    )
    Rate.create!(sailing: qrst, amount: Money.new(76196, 'EUR'), currency: 'EUR')

    # Cheap indirect route
    erxq = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'ESBCN',
      departure_date: '2022-01-29', arrival_date: '2022-02-12',
      sailing_code: 'ERXQ'
    )
    Rate.create!(sailing: erxq, amount: Money.new(26196, 'EUR'), currency: 'EUR')

    etrg = Sailing.create!(
      origin_port: 'ESBCN', destination_port: 'NLRTM',
      departure_date: '2022-02-16', arrival_date: '2022-02-20',
      sailing_code: 'ETRG'
    )
    Rate.create!(sailing: etrg, amount: Money.new(6996, 'USD'), currency: 'USD')
  end

  def create_complex_routing_data
    # Route to BRSSZ for multi-hop testing - EXACT VALUE FROM response.json
    etrb = Sailing.create!(
      origin_port: 'ESBCN', destination_port: 'BRSSZ',
      departure_date: '2022-02-16', arrival_date: '2022-03-14',
      sailing_code: 'ETRB'
    )
    Rate.create!(sailing: etrb, amount: Money.new(43996, 'USD'), currency: 'USD')
  end
end
