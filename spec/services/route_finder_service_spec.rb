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
    let(:mock_strategy) { instance_double(RouteStrategies::Fastest) }
    let(:mock_route) { [ build_stubbed(:sailing) ] }

    before do
      allow(mock_strategy).to receive(:find_route).and_return(mock_route)
    end

    context 'with strategy delegation' do
      it 'delegates to Fastest strategy' do
        allow(RouteStrategies::Fastest).to receive(:new).with(data_repository).and_return(mock_strategy)
        result = service.find_route(origin_port, destination_port, 'fastest')
        expect(result).to eq(mock_route)
        expect(RouteStrategies::Fastest).to have_received(:new).with(data_repository)
        expect(mock_strategy).to have_received(:find_route).with(origin_port, destination_port)
      end

      it 'delegates to Cheapest strategy' do
        allow(RouteStrategies::Cheapest).to receive(:new).with(data_repository).and_return(mock_strategy)
        result = service.find_route(origin_port, destination_port, 'cheapest')
        expect(result).to eq(mock_route)
      end

      it 'delegates to CheapestDirect strategy' do
        allow(RouteStrategies::CheapestDirect).to receive(:new).with(data_repository).and_return(mock_strategy)
        result = service.find_route(origin_port, destination_port, 'cheapest-direct')
        expect(result).to eq(mock_route)
      end
    end

    context 'with error handling' do
      it 'raises ArgumentError for unknown criteria' do
        expect {
          service.find_route(origin_port, destination_port, 'unknown')
        }.to raise_error(ArgumentError, 'Unknown criteria: unknown')

        expect {
          service.find_route(origin_port, destination_port, nil)
        }.to raise_error(ArgumentError, 'Unknown criteria: ')
      end

      it 'propagates strategy errors' do
        allow(RouteStrategies::Fastest).to receive(:new).with(data_repository).and_return(mock_strategy)
        allow(mock_strategy).to receive(:find_route).and_raise(StandardError, 'Strategy error')

        expect {
          service.find_route('CNSHA', 'NLRTM', 'fastest')
        }.to raise_error(StandardError, 'Strategy error')
      end
    end

    context 'with different port combinations' do
      it 'passes correct ports to strategy' do
        allow(RouteStrategies::Fastest).to receive(:new).with(data_repository).and_return(mock_strategy)
        service.find_route('ESBCN', 'BRSSZ', 'fastest')
        expect(mock_strategy).to have_received(:find_route).with('ESBCN', 'BRSSZ')
      end
    end
  end

  describe 'STRATEGY_MAP constant' do
    it 'contains correct strategy mappings and is immutable' do
      expect(described_class::STRATEGY_MAP).to include(
        'fastest' => RouteStrategies::Fastest,
        'cheapest' => RouteStrategies::Cheapest,
        'cheapest-direct' => RouteStrategies::CheapestDirect
      )
      expect(described_class::STRATEGY_MAP).to be_frozen
      expect(described_class::STRATEGY_MAP.size).to eq(3)
    end
  end
end
