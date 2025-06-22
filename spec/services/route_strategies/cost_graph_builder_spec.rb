require 'rails_helper'

RSpec.describe RouteStrategies::CostGraphBuilder do
  subject(:builder) { described_class.new(currency_converter) }
  let(:currency_converter) { instance_double('CurrencyConverter') }

  describe '#build_from_sailings' do
    context 'with valid sailings' do
      let(:shanghai_to_barcelona) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'ESBCN',
        departure_date: Date.parse('2022-01-29'),
        arrival_date: Date.parse('2022-02-12'),
        sailing_code: 'ERXQ'
      ) }

      let(:barcelona_to_rotterdam) { build_stubbed(:sailing,
        origin_port: 'ESBCN',
        destination_port: 'NLRTM',
        departure_date: Date.parse('2022-02-16'),
        arrival_date: Date.parse('2022-02-20'),
        sailing_code: 'ETRG'
      ) }

      let(:shanghai_rate) { instance_double('Rate', amount: Money.new(26196, 'EUR')) }
      let(:barcelona_rate) { instance_double('Rate', amount: Money.new(6996, 'USD')) }

      before do
        allow(shanghai_to_barcelona).to receive(:rate).and_return(shanghai_rate)
        allow(barcelona_to_rotterdam).to receive(:rate).and_return(barcelona_rate)

        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(26196, 'EUR'), Date.parse('2022-01-29'))
          .and_return(Money.new(26196, 'EUR'))

        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(6996, 'USD'), Date.parse('2022-02-16'))
          .and_return(Money.new(6093, 'EUR'))
      end

      it 'creates graph with correct structure' do
        sailings = [ shanghai_to_barcelona, barcelona_to_rotterdam ]

        result = builder.build_from_sailings(sailings)

        expect(result.keys).to contain_exactly('CNSHA', 'ESBCN')
        expect(result['CNSHA'].size).to eq(1)
        expect(result['ESBCN'].size).to eq(1)
      end

      it 'creates correct edge structure for each sailing' do
        sailings = [ shanghai_to_barcelona ]

        result = builder.build_from_sailings(sailings)
        edge = result['CNSHA'].first

        expect(edge[:sailing]).to eq(shanghai_to_barcelona)
        expect(edge[:destination]).to eq('ESBCN')
        expect(edge[:cost_cents]).to eq(26196)
        expect(edge[:departure_date]).to eq(shanghai_to_barcelona.departure_date)
        expect(edge[:arrival_date]).to eq(shanghai_to_barcelona.arrival_date)
      end

      it 'builds multi-port graph correctly' do
        direct_route = build_stubbed(:sailing,
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          sailing_code: 'MNOP'
        )
        direct_rate = instance_double('Rate', amount: Money.new(45678, 'USD'))
        allow(direct_route).to receive(:rate).and_return(direct_rate)

        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(45678, 'USD'), direct_route.departure_date)
          .and_return(Money.new(41013, 'EUR'))

        sailings = [ shanghai_to_barcelona, barcelona_to_rotterdam, direct_route ]

        result = builder.build_from_sailings(sailings)

        expect(result['CNSHA'].size).to eq(2) # Two routes from Shanghai
        expect(result['ESBCN'].size).to eq(1)  # One route from Barcelona
      end
    end

    context 'with sailings without rates' do
      it 'excludes sailings that have no rate' do
        sailing_with_rate = build_stubbed(:sailing, origin_port: 'CNSHA')
        sailing_without_rate = build_stubbed(:sailing, origin_port: 'ESBCN')
        rate = instance_double('Rate', amount: Money.new(26196, 'EUR'))

        allow(sailing_with_rate).to receive(:rate).and_return(rate)
        allow(sailing_without_rate).to receive(:rate).and_return(nil)

        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(26196, 'EUR'), sailing_with_rate.departure_date)
          .and_return(Money.new(26196, 'EUR'))

        sailings = [ sailing_with_rate, sailing_without_rate ]

        result = builder.build_from_sailings(sailings)

        expect(result.keys).to contain_exactly('CNSHA')
        expect(result['ESBCN']).to be_empty
      end
    end

    context 'with empty sailings array' do
      it 'returns empty graph' do
        result = builder.build_from_sailings([])

        expect(result).to be_empty
      end
    end

    context 'with multiple sailings from same port' do
      let(:first_sailing) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'NLRTM',
        sailing_code: 'ABCD'
      ) }

      let(:second_sailing) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'NLRTM',
        sailing_code: 'EFGH'
      ) }

      let(:first_rate) { instance_double('Rate', amount: Money.new(58930, 'USD')) }
      let(:second_rate) { instance_double('Rate', amount: Money.new(89032, 'EUR')) }

      before do
        allow(first_sailing).to receive(:rate).and_return(first_rate)
        allow(second_sailing).to receive(:rate).and_return(second_rate)

        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(58930, 'USD'), first_sailing.departure_date)
          .and_return(Money.new(58930, 'EUR'))

        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(89032, 'EUR'), second_sailing.departure_date)
          .and_return(Money.new(89032, 'EUR'))
      end

      it 'includes all sailings as separate edges' do
        sailings = [ first_sailing, second_sailing ]

        result = builder.build_from_sailings(sailings)

        expect(result['CNSHA'].size).to eq(2)
        sailing_codes = result['CNSHA'].map { |edge| edge[:sailing].sailing_code }
        expect(sailing_codes).to contain_exactly('ABCD', 'EFGH')
      end
    end

    context 'with real response.json data structure' do
      before do
        # Setup exchange rates for cost calculations
        ExchangeRate.create!(departure_date: Date.parse('2022-01-29'), currency: 'usd', rate: 1.1138)
        ExchangeRate.create!(departure_date: Date.parse('2022-02-16'), currency: 'usd', rate: 1.1482)
      end

      it 'correctly processes Barcelona route from response.json' do
        erxq = create(:sailing,
          origin_port: 'CNSHA', destination_port: 'ESBCN',
          departure_date: Date.parse('2022-01-29'),
          arrival_date: Date.parse('2022-02-12'),
          sailing_code: 'ERXQ'
        )
        create(:rate, sailing: erxq, amount: Money.new(26196, 'EUR'), currency: 'EUR')

        etrg = create(:sailing,
          origin_port: 'ESBCN', destination_port: 'NLRTM',
          departure_date: Date.parse('2022-02-16'),
          arrival_date: Date.parse('2022-02-20'),
          sailing_code: 'ETRG'
        )
        create(:rate, sailing: etrg, amount: Money.new(6996, 'USD'), currency: 'USD')

        # Mock currency converter for the real objects
        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(26196, 'EUR'), Date.parse('2022-01-29'))
          .and_return(Money.new(26196, 'EUR'))

        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(6996, 'USD'), Date.parse('2022-02-16'))
          .and_return(Money.new(6093, 'EUR'))

        sailings = [ erxq, etrg ]

        result = builder.build_from_sailings(sailings)

        # Verify Barcelona leg
        barcelona_edge = result['CNSHA'].first
        expect(barcelona_edge[:cost_cents]).to eq(26196) # €261.96

        # Verify Rotterdam leg
        rotterdam_edge = result['ESBCN'].first
        expect(rotterdam_edge[:cost_cents]).to eq(6093) # $69.96 / 1.1482 ≈ €60.93
      end
    end
  end

  describe '#create_cost_edge (private method)' do
    let(:sailing) { build_stubbed(:sailing,
      origin_port: 'CNSHA',
      destination_port: 'ESBCN',
      departure_date: Date.parse('2022-01-29'),
      arrival_date: Date.parse('2022-02-12')
    ) }

    let(:rate) { instance_double('Rate', amount: Money.new(26196, 'EUR')) }

    before do
      allow(sailing).to receive(:rate).and_return(rate)
      allow(currency_converter).to receive(:convert_to_eur)
        .with(Money.new(26196, 'EUR'), sailing.departure_date)
        .and_return(Money.new(26196, 'EUR'))
    end

    it 'creates edge with all required fields' do
      edge = builder.send(:create_cost_edge, sailing)

      expect(edge).to include(
        sailing: sailing,
        destination: 'ESBCN',
        cost_cents: 26196,
        departure_date: sailing.departure_date,
        arrival_date: sailing.arrival_date
      )
    end

    it 'preserves sailing object reference' do
      edge = builder.send(:create_cost_edge, sailing)

      expect(edge[:sailing]).to be(sailing)
    end
  end
end
