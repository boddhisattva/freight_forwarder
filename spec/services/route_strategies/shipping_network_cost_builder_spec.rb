require 'rails_helper'

RSpec.describe RouteStrategies::ShippingNetworkCostBuilder do
  subject(:builder) { described_class.new(currency_converter) }
  let(:currency_converter) { instance_double('CurrencyConverter') }

  describe '#build_from_sailings' do
    context 'cost-specific behavior' do
      let(:sailing) { build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'ESBCN',
        departure_date: Date.parse('2022-01-29'),
        arrival_date: Date.parse('2022-02-12'),
        sailing_code: 'ERXQ'
      ) }

      let(:rate) { instance_double('Rate', amount: Money.new(26196, 'EUR')) }

      before do
        allow(sailing).to receive(:rate).and_return(rate)
        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(26196, 'EUR'), Date.parse('2022-01-29'))
          .and_return(Money.new(26196, 'EUR'))
      end

      it 'creates cost-optimized route option with EUR conversion' do
        result = builder.build_from_sailings([ sailing ])
        edge = result['CNSHA'].first

        expect(edge[:sailing]).to eq(sailing)
        expect(edge[:destination]).to eq('ESBCN')
        expect(edge[:cost_cents]).to eq(26196)
        expect(edge[:departure_date]).to eq(sailing.departure_date)
        expect(edge[:arrival_date]).to eq(sailing.arrival_date)
      end

      it 'converts USD rates to EUR using departure date' do
        usd_sailing = build_stubbed(:sailing,
          departure_date: Date.parse('2022-02-16'),
          sailing_code: 'ETRG'
        )
        usd_rate = instance_double('Rate', amount: Money.new(6996, 'USD'))

        allow(usd_sailing).to receive(:rate).and_return(usd_rate)
        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(6996, 'USD'), Date.parse('2022-02-16'))
          .and_return(Money.new(6093, 'EUR'))

        result = builder.build_from_sailings([ usd_sailing ])
        edge = result[usd_sailing.origin_port].first

        expect(edge[:cost_cents]).to eq(6093)
        expect(currency_converter).to have_received(:convert_to_eur)
          .with(Money.new(6996, 'USD'), Date.parse('2022-02-16'))
      end

      it 'handles multiple currencies in single request' do
        eur_sailing = build_stubbed(:sailing, sailing_code: 'EUR1')
        usd_sailing = build_stubbed(:sailing, sailing_code: 'USD1')

        eur_rate = instance_double('Rate', amount: Money.new(10000, 'EUR'))
        usd_rate = instance_double('Rate', amount: Money.new(15000, 'USD'))

        allow(eur_sailing).to receive(:rate).and_return(eur_rate)
        allow(usd_sailing).to receive(:rate).and_return(usd_rate)

        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(10000, 'EUR'), eur_sailing.departure_date)
          .and_return(Money.new(10000, 'EUR'))
        allow(currency_converter).to receive(:convert_to_eur)
          .with(Money.new(15000, 'USD'), usd_sailing.departure_date)
          .and_return(Money.new(13043, 'EUR'))

        result = builder.build_from_sailings([ eur_sailing, usd_sailing ])

        eur_edge = result[eur_sailing.origin_port].find { |e| e[:sailing] == eur_sailing }
        usd_edge = result[usd_sailing.origin_port].find { |e| e[:sailing] == usd_sailing }

        expect(eur_edge[:cost_cents]).to eq(10000)
        expect(usd_edge[:cost_cents]).to eq(13043)
      end
    end

    context 'cost calculation edge cases' do
      it 'handles zero-cost sailings correctly' do
        free_sailing = build_stubbed(:sailing)
        free_rate = instance_double('Rate', amount: Money.new(0, 'EUR'))

        allow(free_sailing).to receive(:rate).and_return(free_rate)
        allow(currency_converter).to receive(:convert_to_eur)
          .and_return(Money.new(0, 'EUR'))

        result = builder.build_from_sailings([ free_sailing ])
        edge = result[free_sailing.origin_port].first

        expect(edge[:cost_cents]).to eq(0)
      end
    end
  end

  describe 'currency conversion delegation' do
    it 'delegates currency conversion with correct parameters' do
      sailing = build_stubbed(:sailing, departure_date: Date.parse('2022-01-15'))
      rate = instance_double('Rate', amount: Money.new(5000, 'JPY'))

      allow(sailing).to receive(:rate).and_return(rate)
      allow(currency_converter).to receive(:convert_to_eur)
        .with(Money.new(5000, 'JPY'), Date.parse('2022-01-15'))
        .and_return(Money.new(3830, 'EUR'))

      builder.build_from_sailings([ sailing ])

      expect(currency_converter).to have_received(:convert_to_eur)
        .with(Money.new(5000, 'JPY'), Date.parse('2022-01-15'))
    end
  end
end
