# == Schema Information
#
# Table name: exchange_rates
#
#  id             :bigint           not null, primary key
#  currency       :string(3)        not null
#  departure_date :datetime         not null
#  rate           :decimal(10, 6)   not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_exchange_rates_on_departure_date               (departure_date)
#  index_exchange_rates_on_departure_date_and_currency  (departure_date,currency) UNIQUE
#
require 'rails_helper'

RSpec.describe ExchangeRate, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:departure_date) }
    it { should validate_presence_of(:rate) }
    it { should validate_presence_of(:currency) }

    it 'validates rate is greater than zero and handles edge cases' do
      # Positive rates should be valid
      expect(build(:exchange_rate, rate: 1.1138)).to be_valid
      expect(build(:exchange_rate, rate: 999999.999999)).to be_valid

      # Zero and negative rates should be invalid
      expect(build(:exchange_rate, rate: 0)).not_to be_valid
      expect(build(:exchange_rate, rate: -1.5)).not_to be_valid
    end

    it 'validates uniqueness of currency scoped to departure_date' do
      existing_rate = create(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'USD', rate: 1.1138)
      existing_rate2 = build(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'JPY', rate: 1.1538)
      duplicate_rate = build(:exchange_rate, departure_date: existing_rate.departure_date, currency: existing_rate.currency, rate: 1.2000)
      expect(duplicate_rate).not_to be_valid
      expect(duplicate_rate.errors[:currency]).to include('has already been taken')

      # Different currency on same date should be valid
      different_currency = build(:exchange_rate, departure_date: existing_rate.departure_date, currency: 'JPY', rate: 1.1538)
      expect(different_currency).to be_valid
    end
  end

  describe 'scopes' do
    before do
      create(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'usd', rate: 1.1138)
      create(:exchange_rate, departure_date: Date.parse('2022-01-30'), currency: 'usd', rate: 1.1156)
    end

    describe '.for_departure_date' do
      it 'returns rates for specific departure date' do
        rates = ExchangeRate.for_departure_date(Date.parse('2022-01-29'))
        expect(rates.count).to eq(1)
        expect(rates.first.currency).to eq('usd')
      end
    end

    describe '.for_currency' do
      it 'returns rates for specific currency (case insensitive)' do
        expect(ExchangeRate.for_currency('usd').count).to eq(2)
        expect(ExchangeRate.for_currency('USD').count).to eq(2)
      end
    end

    describe '.for_departure_date_and_currency' do
      it 'finds specific rate and handles case sensitivity' do
        rate = ExchangeRate.for_departure_date_and_currency(Date.parse('2022-01-29'), 'USD')
        expect(rate.rate).to eq(BigDecimal('1.1138'))

        # Should return nil for EUR (not in data) or non-existent dates
        expect(ExchangeRate.for_departure_date_and_currency(Date.parse('2022-01-29'), 'EUR')).to be_nil
        expect(ExchangeRate.for_departure_date_and_currency(Date.parse('2022-12-31'), 'USD')).to be_nil
      end
    end
  end
end
