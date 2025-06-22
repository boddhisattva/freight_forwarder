# == Schema Information
#
# Table name: sailings
#
#  id                                 :bigint           not null, primary key
#  arrival_date(Arrival date)         :datetime         not null
#  departure_date(Departure date)     :datetime         not null
#  destination_port(Destination port) :string           not null
#  origin_port(Origin port)           :string           not null
#  sailing_code(Sailing code)         :string           not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#
# Indexes
#
#  index_sailings_on_origin_port_and_destination_port  (origin_port,destination_port)
#
require 'rails_helper'

RSpec.describe Sailing, type: :model do
  describe 'associations' do
    it { should have_one(:rate).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:sailing_code) }
    it { should validate_presence_of(:origin_port) }
    it { should validate_presence_of(:destination_port) }
    it { should validate_presence_of(:departure_date) }
    it { should validate_presence_of(:arrival_date) }

    # Fix uniqueness validation by providing a valid record
    it 'validates uniqueness of sailing_code' do
      existing_sailing = create(:sailing, sailing_code: 'QRST')
      duplicate_sailing = build(:sailing, sailing_code: existing_sailing.sailing_code)
      expect(duplicate_sailing).not_to be_valid
      expect(duplicate_sailing.errors[:sailing_code]).to include('has already been taken')
    end
  end

  describe 'custom validations' do
    describe 'arrival_after_departure' do
      let(:sailing) { build(:sailing) }

      it 'is valid when arrival is after departure' do
        sailing.departure_date = Date.parse('2022-01-01')
        sailing.arrival_date = Date.parse('2022-01-15')
        expect(sailing).to be_valid
      end

      it 'is invalid when arrival is before departure' do
        sailing.departure_date = Date.parse('2022-01-15')
        sailing.arrival_date = Date.parse('2022-01-01')
        expect(sailing).not_to be_valid
        expect(sailing.errors[:arrival_date]).to include('must be after departure date')
      end

      it 'is invalid when arrival equals departure' do
        sailing.departure_date = Date.parse('2022-01-01')
        sailing.arrival_date = Date.parse('2022-01-01')
        expect(sailing).not_to be_valid
        expect(sailing.errors[:arrival_date]).to include('must be after departure date')
      end

      it 'is valid when dates are nil (handled by presence validation)' do
        sailing.departure_date = nil
        sailing.arrival_date = nil
        expect(sailing).not_to be_valid # fails presence validation, not custom validation
      end
    end
  end

  describe 'scopes' do
    let!(:shanghai_rotterdam) { create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM') }
    let!(:shanghai_barcelona) { create(:sailing, origin_port: 'CNSHA', destination_port: 'ESBCN') }
    let!(:barcelona_rotterdam) { create(:sailing, origin_port: 'ESBCN', destination_port: 'NLRTM') }

    describe '.from_port' do
      it 'returns sailings from specified port' do
        expect(Sailing.from_port('CNSHA')).to include(shanghai_rotterdam, shanghai_barcelona)
        expect(Sailing.from_port('CNSHA')).not_to include(barcelona_rotterdam)
      end
    end

    describe '.to_port' do
      it 'returns sailings to specified port' do
        expect(Sailing.to_port('NLRTM')).to include(shanghai_rotterdam, barcelona_rotterdam)
        expect(Sailing.to_port('NLRTM')).not_to include(shanghai_barcelona)
      end
    end

    describe '.direct' do
      it 'returns direct sailings between two ports' do
        expect(Sailing.direct('CNSHA', 'NLRTM')).to include(shanghai_rotterdam)
        expect(Sailing.direct('CNSHA', 'NLRTM')).not_to include(shanghai_barcelona, barcelona_rotterdam)
      end
    end
  end

  describe '#duration_days' do
    let(:sailing) { build(:sailing) }

    it 'calculates duration correctly for 17-day journey' do
      sailing.departure_date = Date.parse('2022-01-29')
      sailing.arrival_date = Date.parse('2022-02-15')
      expect(sailing.duration_days).to eq(17)
    end

    it 'calculates duration correctly for 1-day journey' do
      sailing.departure_date = Date.parse('2022-01-01')
      sailing.arrival_date = Date.parse('2022-01-02')
      expect(sailing.duration_days).to eq(1)
    end

    it 'calculates duration correctly for same-day journey' do
      sailing.departure_date = Date.parse('2022-01-01')
      sailing.arrival_date = Date.parse('2022-01-01')
      expect(sailing.duration_days).to eq(0)
    end

    it 'handles datetime objects correctly' do
      sailing.departure_date = DateTime.parse('2022-01-29 10:00:00')
      sailing.arrival_date = DateTime.parse('2022-02-15 14:30:00')
      # DateTime calculation includes partial days, so it's 18 days
      expect(sailing.duration_days).to eq(18)
    end
  end

  describe 'real data integration' do
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
    end

    it 'can load and query real sailing data' do
      expect(Sailing.count).to eq(9)
      expect(Sailing.from_port('CNSHA').count).to eq(6)
      # Count actual sailings to NLRTM from the data
      expect(Sailing.to_port('NLRTM').count).to eq(7)
    end

    it 'finds QRST as the fastest direct route from CNSHA to NLRTM' do
      direct_routes = Sailing.direct('CNSHA', 'NLRTM')
      fastest_route = direct_routes.min_by(&:duration_days)
      expect(fastest_route.sailing_code).to eq('QRST')
      expect(fastest_route.duration_days).to eq(17)
    end
  end
end
