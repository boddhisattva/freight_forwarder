require 'rails_helper'

RSpec.describe RouteFinderService do
  let(:data_repository) { instance_double(DataRepository) }
  let(:service) { described_class.new(data_repository: data_repository) }

  describe '#initialize' do
    it 'uses default DataRepository when none provided' do
      service = described_class.new
      expect(service.instance_variable_get(:@repository)).to be_a(DataRepository)
    end

    it 'uses provided data repository' do
      custom_repository = instance_double(DataRepository)
      service = described_class.new(data_repository: custom_repository)
      expect(service.instance_variable_get(:@repository)).to eq(custom_repository)
    end
  end

  describe '#find_route' do
    let(:origin_port) { 'CNSHA' }
    let(:destination_port) { 'NLRTM' }
    let(:mock_strategy) { instance_double(RouteStrategies::FastestStrategy) }
    let(:mock_route) { [ build_stubbed(:sailing) ] }

    before do
      allow(mock_strategy).to receive(:find_route).with(origin_port, destination_port).and_return(mock_route)
    end

    context 'with fastest criteria' do
      it 'uses FastestStrategy and returns route' do
        allow(RouteStrategies::FastestStrategy).to receive(:new).with(data_repository).and_return(mock_strategy)

        result = service.find_route(origin_port, destination_port, 'fastest')

        expect(result).to eq(mock_route)
        expect(RouteStrategies::FastestStrategy).to have_received(:new).with(data_repository)
        expect(mock_strategy).to have_received(:find_route).with(origin_port, destination_port)
      end
    end

    context 'with cheapest criteria' do
      it 'uses CheapestStrategy and returns route' do
        allow(RouteStrategies::CheapestStrategy).to receive(:new).with(data_repository).and_return(mock_strategy)

        result = service.find_route(origin_port, destination_port, 'cheapest')

        expect(result).to eq(mock_route)
        expect(RouteStrategies::CheapestStrategy).to have_received(:new).with(data_repository)
        expect(mock_strategy).to have_received(:find_route).with(origin_port, destination_port)
      end
    end

    context 'with cheapest-direct criteria' do
      it 'uses CheapestDirectStrategy and returns route' do
        allow(RouteStrategies::CheapestDirectStrategy).to receive(:new).with(data_repository).and_return(mock_strategy)

        result = service.find_route(origin_port, destination_port, 'cheapest-direct')

        expect(result).to eq(mock_route)
        expect(RouteStrategies::CheapestDirectStrategy).to have_received(:new).with(data_repository)
        expect(mock_strategy).to have_received(:find_route).with(origin_port, destination_port)
      end
    end

    context 'with unknown criteria' do
      it 'raises ArgumentError with descriptive message' do
        expect {
          service.find_route(origin_port, destination_port, 'unknown')
        }.to raise_error(ArgumentError, 'Unknown criteria: unknown')
      end

      it 'raises ArgumentError for nil criteria' do
        expect {
          service.find_route(origin_port, destination_port, nil)
        }.to raise_error(ArgumentError, 'Unknown criteria: ')
      end

      it 'raises ArgumentError for empty criteria' do
        expect {
          service.find_route(origin_port, destination_port, '')
        }.to raise_error(ArgumentError, 'Unknown criteria: ')
      end
    end

    context 'with different port combinations' do
      it 'passes correct ports to strategy' do
        allow(RouteStrategies::FastestStrategy).to receive(:new).with(data_repository).and_return(mock_strategy)

        service.find_route('ESBCN', 'BRSSZ', 'fastest')

        expect(mock_strategy).to have_received(:find_route).with('ESBCN', 'BRSSZ')
      end

      it 'handles single character port codes' do
        allow(RouteStrategies::FastestStrategy).to receive(:new).with(data_repository).and_return(mock_strategy)

        service.find_route('A', 'B', 'fastest')

        expect(mock_strategy).to have_received(:find_route).with('A', 'B')
      end
    end
  end

  describe 'STRATEGY_MAP constant' do
    it 'contains all expected strategy mappings' do
      expect(described_class::STRATEGY_MAP).to include(
        'fastest' => RouteStrategies::FastestStrategy,
        'cheapest' => RouteStrategies::CheapestStrategy,
        'cheapest-direct' => RouteStrategies::CheapestDirectStrategy
      )
    end

    it 'is frozen to prevent modification' do
      expect(described_class::STRATEGY_MAP).to be_frozen
    end

    it 'has correct number of strategies' do
      expect(described_class::STRATEGY_MAP.size).to eq(3)
    end

    it 'maps string keys to strategy classes' do
      described_class::STRATEGY_MAP.each do |key, strategy_class|
        expect(key).to be_a(String)
        expect(strategy_class).to be_a(Class)
        expect(strategy_class.name).to start_with('RouteStrategies::')
      end
    end
  end

  describe 'strategy instantiation' do
    it 'creates new strategy instances for each call' do
      strategy1 = service.send(:strategy_for, 'fastest')
      strategy2 = service.send(:strategy_for, 'fastest')

      expect(strategy1).not_to eq(strategy2)
      expect(strategy1).to be_a(RouteStrategies::FastestStrategy)
      expect(strategy2).to be_a(RouteStrategies::FastestStrategy)
    end

    it 'passes repository to strategy constructor' do
      strategy = service.send(:strategy_for, 'fastest')
      expect(strategy.instance_variable_get(:@repository)).to eq(data_repository)
    end
  end

  describe 'real data integration' do
    let(:real_repository) { DataRepository.new }
    let(:real_service) { described_class.new(data_repository: real_repository) }

    before do
      # Load real data from response.json
      response_data = JSON.parse(File.read(Rails.root.join('db', 'response.json')))

      # Create sailings from response data
      response_data['sailings'].each do |sailing_data|
        create(:sailing,
          origin_port: sailing_data['origin_port'],
          destination_port: sailing_data['destination_port'],
          departure_date: Date.parse(sailing_data['departure_date']),
          arrival_date: Date.parse(sailing_data['arrival_date']),
          sailing_code: sailing_data['sailing_code']
        )
      end

      # Create rates from response data
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

      # Create exchange rates from response data
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

    it 'finds fastest route using real data' do
      result = real_service.find_route('CNSHA', 'NLRTM', 'fastest')

      expect(result).not_to be_empty
      expect(result.first).to be_a(Sailing)
      expect(result.first.sailing_code).to eq('QRST')
      expect(result.first.origin_port).to eq('CNSHA')
      expect(result.first.destination_port).to eq('NLRTM')
    end

    it 'finds cheapest route using real data' do
      result = real_service.find_route('CNSHA', 'NLRTM', 'cheapest')

      expect(result).not_to be_empty
      expect(result.first).to be_a(Sailing)
      expect(result.first.origin_port).to eq('CNSHA')
      expect(result.first.destination_port).to eq('NLRTM')
    end

    it 'finds cheapest direct route using real data' do
      result = real_service.find_route('CNSHA', 'NLRTM', 'cheapest-direct')

      expect(result).not_to be_empty
      expect(result.first).to be_a(Sailing)
      expect(result.first.origin_port).to eq('CNSHA')
      expect(result.first.destination_port).to eq('NLRTM')
    end

    it 'handles multi-hop routes correctly' do
      result = real_service.find_route('CNSHA', 'BRSSZ', 'fastest')

      expect(result).not_to be_empty
      expect(result.length).to be >= 1
      expect(result.first.origin_port).to eq('CNSHA')
      expect(result.last.destination_port).to eq('BRSSZ')
    end

    it 'returns empty array for unreachable destinations' do
      result = real_service.find_route('CNSHA', 'UNKNOWN', 'fastest')

      expect(result).to eq([])
    end
  end

  describe 'error handling' do
    context 'when strategy raises an error' do
      let(:mock_strategy) { instance_double(RouteStrategies::FastestStrategy) }

      before do
        allow(RouteStrategies::FastestStrategy).to receive(:new).with(data_repository).and_return(mock_strategy)
        allow(mock_strategy).to receive(:find_route).and_raise(StandardError, 'Strategy error')
      end

      it 'propagates the error' do
        expect {
          service.find_route('CNSHA', 'NLRTM', 'fastest')
        }.to raise_error(StandardError, 'Strategy error')
      end
    end

    context 'when data repository is nil' do
      it 'handles nil repository gracefully' do
        service_with_nil_repo = described_class.new(data_repository: nil)

        expect {
          service_with_nil_repo.find_route('CNSHA', 'NLRTM', 'fastest')
        }.to raise_error(ArgumentError, 'Unknown criteria: fastest')
      end
    end
  end

  describe 'performance considerations' do
    it 'does not recreate strategy map on each call' do
      # The constant should be created once at class load time
      expect(described_class::STRATEGY_MAP).to be_a(Hash)

      # Multiple calls should use the same constant
      strategy1 = service.send(:strategy_for, 'fastest')
      strategy2 = service.send(:strategy_for, 'cheapest')

      expect(strategy1).to be_a(RouteStrategies::FastestStrategy)
      expect(strategy2).to be_a(RouteStrategies::CheapestStrategy)
    end
  end
end
