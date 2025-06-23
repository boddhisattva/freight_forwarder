require 'rails_helper'

RSpec.describe RouteStrategies::BaseStrategy do
  subject(:strategy) { described_class.new(repository, currency_converter: currency_converter) }

  let(:repository) { double('Repository') }
  let(:currency_converter) { instance_double(CurrencyConverter) }

  describe '#initialize' do
    it 'sets repository and currency_converter' do
      expect(strategy.instance_variable_get(:@repository)).to eq(repository)
      expect(strategy.instance_variable_get(:@currency_converter)).to eq(currency_converter)
    end

    it 'uses default CurrencyConverter when not provided' do
      strategy_with_default = described_class.new(repository)

      expect(strategy_with_default.instance_variable_get(:@currency_converter)).to be_a(CurrencyConverter)
    end
  end
end
