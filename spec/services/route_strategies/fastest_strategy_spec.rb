require 'rails_helper'

RSpec.describe RouteStrategies::FastestStrategy do
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
  end
end
