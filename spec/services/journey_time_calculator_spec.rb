require 'rails_helper'

RSpec.describe JourneyTimeCalculator do
  let(:calculator) { described_class.new }

  describe '#calculate_total_time' do
    let(:departure_date) { Date.parse('2022-02-16') }
    let(:arrival_date) { Date.parse('2022-02-20') }

    context 'when first sailing (no layover)' do
      it 'returns sailing duration only' do
        total_time = calculator.calculate_total_time(nil, departure_date, arrival_date)
        expect(total_time).to eq(4) # 4 days sailing
      end
    end

    context 'when connecting sailing (with layover)' do
      let(:previous_arrival) { Date.parse('2022-02-12') }

      it 'returns layover time plus sailing time' do
        total_time = calculator.calculate_total_time(previous_arrival, departure_date, arrival_date)
        expect(total_time).to eq(8) # 4 days layover + 4 days sailing
      end
    end

    context 'when no layover needed (immediate connection)' do
      let(:previous_arrival) { Date.parse('2022-02-16') }

      it 'returns sailing time only when no waiting required' do
        total_time = calculator.calculate_total_time(previous_arrival, departure_date, arrival_date)
        expect(total_time).to eq(4) # 0 days layover + 4 days sailing
      end
    end
  end
end
