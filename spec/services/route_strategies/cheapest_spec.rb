require 'rails_helper'

RSpec.describe RouteStrategies::Cheapest do
  subject(:strategy) { described_class.new(repository) }
  let(:repository) { DataRepository.new }

  describe '#find_route using Bellman-Ford algorithm' do
    context 'with response.json data (CNSHA to NLRTM)' do
      before do
        create_minimal_cost_data
      end

      it 'chooses cheapest route (Barcelona) over MNOP direct route with expected output format' do
        result = strategy.find_route('CNSHA', 'NLRTM')

        # Barcelona route: €261.96 + $69.96/1.1482 = €322.85 (cheaper)
        # vs MNOP: $456.78/1.1138 = €410.13 (more expensive)
        expect(result.size).to eq(2)
        expect(result.first[:sailing_code]).to eq('ERXQ')
        expect(result.last[:sailing_code]).to eq('ETRG')

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

    context 'with basic multi-hop routing' do
      before do
        create_simple_multi_hop_data
      end

      it 'finds cheaper 3-leg route over expensive direct route' do
        result = strategy.find_route('CNSHA', 'USNYC')

        # Should find 3-leg route: CNSHA->ESBCN->DEHAM->USNYC
        expect(result.size).to eq(3)
        expect(result[0][:sailing_code]).to eq('LEG1')
        expect(result[1][:sailing_code]).to eq('LEG2')
        expect(result[2][:sailing_code]).to eq('LEG3')
      end

      it 'calculates total cost correctly for multi-leg routes' do
        result = strategy.find_route('CNSHA', 'USNYC')

        total_cost_eur = result.sum do |leg|
          rate = BigDecimal(leg[:rate])
          if leg[:rate_currency] == 'EUR'
            rate
          else
            exchange_rate = ExchangeRate.for_departure_date_and_currency(
              Date.parse(leg[:departure_date]),
              leg[:rate_currency].downcase
            )
            rate / exchange_rate.rate
          end
        end

        expect(total_cost_eur).to be < 500
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

  def create_minimal_cost_data
    # Only exchange rates actually used in cost calculations
    ExchangeRate.create!(departure_date: '2022-01-29', currency: 'usd', rate: 1.1138)
    ExchangeRate.create!(departure_date: '2022-01-30', currency: 'usd', rate: 1.1138)
    ExchangeRate.create!(departure_date: '2022-02-16', currency: 'usd', rate: 1.1482)

    # MNOP direct route - comparison baseline
    mnop = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'NLRTM',
      departure_date: '2022-01-30', arrival_date: '2022-03-05',
      sailing_code: 'MNOP'
    )
    Rate.create!(sailing: mnop, amount: Money.new(45678, 'USD'), currency: 'USD')

    # Barcelona route - cheaper alternative
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

  def create_simple_multi_hop_data
    # Exchange rates for new dates
    ExchangeRate.create!(departure_date: '2022-02-10', currency: 'usd', rate: 1.1400)
    ExchangeRate.create!(departure_date: '2022-02-18', currency: 'usd', rate: 1.1450)

    # Expensive direct route to force multi-hop preference
    direct_expensive = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'USNYC',
      departure_date: '2022-01-30', arrival_date: '2022-03-15',
      sailing_code: 'EXPENSIVE_DIRECT'
    )
    Rate.create!(sailing: direct_expensive, amount: Money.new(100000, 'EUR'), currency: 'EUR')

    # Simple 3-leg route: CNSHA->ESBCN->DEHAM->USNYC
    leg1 = Sailing.create!(
      origin_port: 'CNSHA', destination_port: 'ESBCN',
      departure_date: '2022-01-29', arrival_date: '2022-02-05',
      sailing_code: 'LEG1'
    )
    Rate.create!(sailing: leg1, amount: Money.new(15000, 'EUR'), currency: 'EUR')

    leg2 = Sailing.create!(
      origin_port: 'ESBCN', destination_port: 'DEHAM',
      departure_date: '2022-02-10', arrival_date: '2022-02-14',
      sailing_code: 'LEG2'
    )
    Rate.create!(sailing: leg2, amount: Money.new(8000, 'USD'), currency: 'USD')

    leg3 = Sailing.create!(
      origin_port: 'DEHAM', destination_port: 'USNYC',
      departure_date: '2022-02-18', arrival_date: '2022-02-25',
      sailing_code: 'LEG3'
    )
    Rate.create!(sailing: leg3, amount: Money.new(20000, 'EUR'), currency: 'EUR')
  end
end
