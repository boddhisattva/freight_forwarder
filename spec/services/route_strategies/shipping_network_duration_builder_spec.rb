require 'rails_helper'

RSpec.describe RouteStrategies::ShippingNetworkDurationBuilder do
  subject(:builder) { described_class.new }

  describe '#build_from_sailings' do
    context 'duration-specific behavior' do
      let(:sailing) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'NLRTM',
        departure_date: Date.parse('2022-01-29'),
        arrival_date: Date.parse('2022-02-15'),
        rate: build_stubbed(:rate)
      ) }

      it 'creates duration-optimized route option' do
        result = builder.build_from_sailings([ sailing ])
        route_option = result['CNSHA'].first

        expect(route_option[:sailing]).to eq(sailing)
        expect(route_option[:destination]).to eq('NLRTM')
        expect(route_option[:departure_date]).to eq(sailing.departure_date)
        expect(route_option[:arrival_date]).to eq(sailing.arrival_date)
        expect(route_option[:duration]).to eq(sailing.duration_days)
      end

      it 'calculates duration correctly from sailing dates' do
        short_sailing = build_stubbed(:sailing,
          departure_date: Date.parse('2022-02-01'),
          arrival_date: Date.parse('2022-02-05'),
          rate: build_stubbed(:rate)
        )

        result = builder.build_from_sailings([ short_sailing ])
        route_option = result[short_sailing.origin_port].first

        expect(route_option[:duration]).to eq(4) # 4 days
        expect(route_option[:duration]).to eq(short_sailing.duration_days)
      end

      it 'handles sailings with different durations from same port' do
        quick_sailing = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          departure_date: Date.parse('2022-01-29'),
          arrival_date: Date.parse('2022-02-02'),
          rate: build_stubbed(:rate)
        )

        slow_sailing = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          departure_date: Date.parse('2022-01-30'),
          arrival_date: Date.parse('2022-03-05'),
          rate: build_stubbed(:rate)
        )

        result = builder.build_from_sailings([ quick_sailing, slow_sailing ])
        durations = result['CNSHA'].map { |option| option[:duration] }

        expect(durations).to contain_exactly(
          quick_sailing.duration_days,
          slow_sailing.duration_days
        )
      end
    end

    context 'duration edge cases' do
      it 'handles same-day arrival correctly' do
        same_day_sailing = build_stubbed(:sailing,
          departure_date: Date.parse('2022-01-29'),
          arrival_date: Date.parse('2022-01-29'),
          rate: build_stubbed(:rate)
        )

        result = builder.build_from_sailings([ same_day_sailing ])
        route_option = result[same_day_sailing.origin_port].first

        expect(route_option[:duration]).to eq(0)
      end

      it 'preserves original sailing date information' do
        sailing = build_stubbed(:sailing,
          departure_date: Date.parse('2022-01-29'),
          arrival_date: Date.parse('2022-02-15'),
          rate: build_stubbed(:rate)
        )

        result = builder.build_from_sailings([ sailing ])
        route_option = result[sailing.origin_port].first

        expect(route_option[:departure_date]).to eq(Date.parse('2022-01-29'))
        expect(route_option[:arrival_date]).to eq(Date.parse('2022-02-15'))
      end
    end
  end
end
