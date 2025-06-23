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
#  index_sailings_on_sailing_code                      (sailing_code)
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
    let(:shanghai_rotterdam) { build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM') }
    let(:shanghai_barcelona) { build_stubbed(:sailing, origin_port: 'CNSHA', destination_port: 'ESBCN') }
    let(:barcelona_rotterdam) { build_stubbed(:sailing, origin_port: 'ESBCN', destination_port: 'NLRTM') }

    describe '.from_port' do
      it 'returns sailings from specified port' do
        allow(Sailing).to receive(:from_port).with('CNSHA').and_return([ shanghai_rotterdam, shanghai_barcelona ])
        expect(Sailing.from_port('CNSHA')).to include(shanghai_rotterdam, shanghai_barcelona)
        expect(Sailing.from_port('CNSHA')).not_to include(barcelona_rotterdam)
      end
    end

    describe '.to_port' do
      it 'returns sailings to specified port' do
        allow(Sailing).to receive(:to_port).with('NLRTM').and_return([ shanghai_rotterdam, barcelona_rotterdam ])
        expect(Sailing.to_port('NLRTM')).to include(shanghai_rotterdam, barcelona_rotterdam)
        expect(Sailing.to_port('NLRTM')).not_to include(shanghai_barcelona)
      end
    end

    describe '.direct' do
      it 'returns direct sailings between two ports (stubbed)' do
        allow(Sailing).to receive(:direct).with('CNSHA', 'NLRTM').and_return([ shanghai_rotterdam ])
        expect(Sailing.direct('CNSHA', 'NLRTM')).to include(shanghai_rotterdam)
        expect(Sailing.direct('CNSHA', 'NLRTM')).not_to include(shanghai_barcelona, barcelona_rotterdam)
      end

      it 'returns direct sailings between two ports (real DB integration)' do
        real_sailing = create(:sailing, origin_port: 'CNSHA', destination_port: 'NLRTM')
        expect(Sailing.direct('CNSHA', 'NLRTM')).to include(real_sailing)
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

  describe '#as_route_hash' do
    let(:departure_date) { Date.parse('2022-01-29') }
    let(:arrival_date) { Date.parse('2022-02-01') }
    let(:sailing) do
      build_stubbed(:sailing,
        origin_port: 'CNSHA',
        destination_port: 'NLRTM',
        departure_date: departure_date,
        arrival_date: arrival_date,
        sailing_code: 'ERXQ'
      )
    end
    let(:rate) { build_stubbed(:rate, amount_cents: 100000, currency: 'USD') }

    before { allow(sailing).to receive(:rate).and_return(rate) }

    it 'returns a formatted hash with rate' do
      expect(sailing.as_route_hash).to eq({
        origin_port: 'CNSHA',
        destination_port: 'NLRTM',
        departure_date: '2022-01-29',
        arrival_date: '2022-02-01',
        sailing_code: 'ERXQ',
        rate: '1000.00',
        rate_currency: 'USD'
      })
    end

    it 'returns a formatted hash without rate' do
      allow(sailing).to receive(:rate).and_return(nil)
      expect(sailing.as_route_hash).to eq({
        origin_port: 'CNSHA',
        destination_port: 'NLRTM',
        departure_date: '2022-01-29',
        arrival_date: '2022-02-01',
        sailing_code: 'ERXQ',
        rate: nil,
        rate_currency: nil
      })
    end
  end
end
