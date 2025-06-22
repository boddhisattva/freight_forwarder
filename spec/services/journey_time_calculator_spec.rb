require 'rails_helper'

RSpec.describe JourneyTimeCalculator do
  subject(:calculator) { described_class.new }

  describe '#calculate_total_time' do
    it 'returns sailing duration for direct sailing' do
      result = calculator.calculate_total_time(nil, Date.parse('2022-01-01'), Date.parse('2022-01-10'))
      expect(result).to eq(9)
    end

    it 'returns layover + sailing duration for multi-leg' do
      result = calculator.calculate_total_time(Date.parse('2022-01-01'), Date.parse('2022-01-05'), Date.parse('2022-01-10'))
      # Layover: 4 days, Sailing: 5 days
      expect(result).to eq(9)
    end

    it 'returns 0 layover if next ship departs same day' do
      result = calculator.calculate_total_time(Date.parse('2022-01-01'), Date.parse('2022-01-01'), Date.parse('2022-01-05'))
      expect(result).to eq(4)
    end
  end

  describe '#valid_connection?' do
    let(:prev) { build_stubbed(:sailing, arrival_date: Date.parse('2022-01-01')) }
    let(:curr) { build_stubbed(:sailing, departure_date: Date.parse('2022-01-02')) }

    it 'returns true for first ship' do
      expect(calculator.valid_connection?(nil, curr)).to be true
    end

    it 'returns true if current departs after previous arrives' do
      expect(calculator.valid_connection?(prev, curr)).to be true
    end

    it 'returns false if current departs before previous arrives' do
      curr2 = build_stubbed(:sailing, departure_date: Date.parse('2021-12-31'))
      expect(calculator.valid_connection?(prev, curr2)).to be false
    end
  end
end
