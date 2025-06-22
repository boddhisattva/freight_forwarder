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
    it { should validate_numericality_of(:rate).is_greater_than(0) }
    it { should validate_presence_of(:currency) }

    # Fix uniqueness validation by providing a valid record
    it 'validates uniqueness of currency scoped to departure_date' do
      existing_rate = create(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'USD', rate: 1.1138)
      duplicate_rate = build(:exchange_rate, departure_date: existing_rate.departure_date, currency: existing_rate.currency, rate: 1.2000)
      expect(duplicate_rate).not_to be_valid
      expect(duplicate_rate.errors[:currency]).to include('has already been taken')
    end
  end

  describe 'scopes' do
    let!(:usd_rate_jan29) { create(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'usd', rate: 1.1138) }
    let!(:jpy_rate_jan29) { create(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'jpy', rate: 130.85) }
    let!(:usd_rate_jan30) { create(:exchange_rate, departure_date: Date.parse('2022-01-30'), currency: 'usd', rate: 1.1138) }

    describe '.for_departure_date' do
      it 'returns rates for specific departure date' do
        expect(ExchangeRate.for_departure_date(Date.parse('2022-01-29'))).to include(usd_rate_jan29, jpy_rate_jan29)
        expect(ExchangeRate.for_departure_date(Date.parse('2022-01-29'))).not_to include(usd_rate_jan30)
      end

      it 'returns empty for non-existent date' do
        expect(ExchangeRate.for_departure_date(Date.parse('2022-12-31'))).to be_empty
      end
    end

    describe '.for_currency' do
      it 'returns rates for specific currency' do
        expect(ExchangeRate.for_currency('usd')).to include(usd_rate_jan29, usd_rate_jan30)
        expect(ExchangeRate.for_currency('usd')).not_to include(jpy_rate_jan29)
      end

      it 'is case insensitive' do
        expect(ExchangeRate.for_currency('USD')).to include(usd_rate_jan29, usd_rate_jan30)
      end

      it 'returns empty for non-existent currency' do
        expect(ExchangeRate.for_currency('GBP')).to be_empty
      end
    end
  end

  describe '.for_departure_date_and_currency' do
    let!(:usd_rate) { create(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'usd', rate: 1.1138) }
    let!(:jpy_rate) { create(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'jpy', rate: 130.85) }

    it 'returns rate for specific date and currency' do
      rate = ExchangeRate.for_departure_date_and_currency(Date.parse('2022-01-29'), 'USD')
      expect(rate).to eq(usd_rate)
    end

    it 'returns nil for EUR currency' do
      rate = ExchangeRate.for_departure_date_and_currency(Date.parse('2022-01-29'), 'EUR')
      expect(rate).to be_nil
    end

    it 'returns nil for non-existent date' do
      rate = ExchangeRate.for_departure_date_and_currency(Date.parse('2022-12-31'), 'USD')
      expect(rate).to be_nil
    end

    it 'returns nil for non-existent currency' do
      rate = ExchangeRate.for_departure_date_and_currency(Date.parse('2022-01-29'), 'GBP')
      expect(rate).to be_nil
    end

    it 'is case insensitive for currency' do
      rate = ExchangeRate.for_departure_date_and_currency(Date.parse('2022-01-29'), 'usd')
      expect(rate).to eq(usd_rate)
    end
  end

  describe 'factory' do
    it 'creates valid exchange rate with default values' do
      rate = build(:exchange_rate)
      expect(rate).to be_valid
      expect(rate.departure_date).to eq(DateTime.parse('2025-06-20 16:59:17'))
      expect(rate.currency).to eq('USD')
      expect(rate.rate).to eq(BigDecimal('9.99'))
    end

    it 'creates exchange rate with custom values' do
      rate = build(:exchange_rate,
        departure_date: Date.parse('2022-01-29'),
        currency: 'usd',
        rate: 1.1138
      )
      expect(rate).to be_valid
      expect(rate.departure_date).to eq(Date.parse('2022-01-29'))
      expect(rate.currency).to eq('usd')
      expect(rate.rate).to eq(BigDecimal('1.1138'))
    end
  end

  describe 'real data integration' do
    before do
      response_data = JSON.parse(File.read(Rails.root.join('db', 'response.json')))
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

    it 'can load and query real exchange rate data' do
      expect(ExchangeRate.count).to eq(14) # 7 dates * 2 currencies
      expect(ExchangeRate.for_currency('usd').count).to eq(7)
      expect(ExchangeRate.for_currency('jpy').count).to eq(7)
    end

    it 'finds correct USD rate for specific date' do
      rate = ExchangeRate.for_departure_date_and_currency(Date.parse('2022-01-29'), 'USD')
      expect(rate).to be_present
      expect(rate.rate).to eq(BigDecimal('1.1138'))
    end

    it 'finds correct JPY rate for specific date' do
      rate = ExchangeRate.for_departure_date_and_currency(Date.parse('2022-01-29'), 'JPY')
      expect(rate).to be_present
      expect(rate.rate).to eq(BigDecimal('130.85'))
    end
  end

  describe 'unique constraint' do
    let(:date) { Date.parse('2022-01-29') }

    it 'allows different currencies for same date' do
      create(:exchange_rate, departure_date: date, currency: 'usd', rate: 1.1138)
      create(:exchange_rate, departure_date: date, currency: 'jpy', rate: 130.85)

      expect(ExchangeRate.count).to eq(2)
    end

    it 'prevents duplicate currency for same date' do
      create(:exchange_rate, departure_date: date, currency: 'usd', rate: 1.1138)
      expect {
        create(:exchange_rate, departure_date: date, currency: 'usd', rate: 1.2000)
      }.to raise_error(ActiveRecord::RecordInvalid, /Currency has already been taken/)
    end

    it 'allows same currency for different dates' do
      create(:exchange_rate, departure_date: Date.parse('2022-01-29'), currency: 'usd', rate: 1.1138)
      create(:exchange_rate, departure_date: Date.parse('2022-01-30'), currency: 'usd', rate: 1.1138)

      expect(ExchangeRate.count).to eq(2)
    end
  end

  describe 'rate validation' do
    it 'validates rate is greater than zero' do
      rate = build(:exchange_rate, rate: 0)
      expect(rate).not_to be_valid
      expect(rate.errors[:rate]).to include('must be greater than 0')
    end

    it 'validates rate is greater than zero for negative values' do
      rate = build(:exchange_rate, rate: -1.5)
      expect(rate).not_to be_valid
      expect(rate.errors[:rate]).to include('must be greater than 0')
    end

    it 'accepts positive decimal rates' do
      rate = build(:exchange_rate, rate: 1.1138)
      expect(rate).to be_valid
    end

    it 'accepts large positive rates' do
      rate = build(:exchange_rate, rate: 999999.999999)
      expect(rate).to be_valid
    end
  end
end
