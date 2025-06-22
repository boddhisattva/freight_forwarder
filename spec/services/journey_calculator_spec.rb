require 'rails_helper'

RSpec.describe JourneyCalculator do
  let(:calculator) { described_class.new }
  let(:previous_sailing) { build_stubbed(:sailing, arrival_date: Date.parse('2022-02-12')) }
  let(:current_sailing) { build_stubbed(:sailing, departure_date: Date.parse('2022-02-16')) }

  describe '#valid_connection?' do
    context 'when first sailing of journey' do
      it 'returns true with no previous sailing' do
        expect(calculator.valid_connection?(nil, current_sailing)).to be true
      end
    end

    context 'when valid connection timing' do
      it 'returns true when current sailing departs after previous arrival' do
        expect(calculator.valid_connection?(previous_sailing, current_sailing)).to be true
      end

      it 'returns true when departure equals arrival (same day connection)' do
        same_day_sailing = build_stubbed(:sailing, departure_date: Date.parse('2022-02-12'))
        expect(calculator.valid_connection?(previous_sailing, same_day_sailing)).to be true
      end
    end

    context 'when invalid connection timing' do
      it 'returns false when current sailing departs before previous arrival' do
        early_sailing = build_stubbed(:sailing, departure_date: Date.parse('2022-02-10'))
        expect(calculator.valid_connection?(previous_sailing, early_sailing)).to be false
      end
    end
  end
end
