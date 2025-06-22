# == Schema Information
#
# Table name: rates
#
#  id           :bigint           not null, primary key
#  amount_cents :integer          default(0), not null
#  currency     :string(3)        not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  sailing_id   :bigint           not null
#
# Indexes
#
#  index_rates_on_sailing_id  (sailing_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (sailing_id => sailings.id)
#
require 'rails_helper'

RSpec.describe Rate, type: :model do
  describe 'associations' do
    it { should belong_to(:sailing) }
  end

  describe 'validations' do
    it { should validate_presence_of(:amount_cents) }
    it { should validate_numericality_of(:amount_cents).is_greater_than(0) }
    it { should validate_presence_of(:currency) }
  end

  describe 'Money gem integration' do
    let(:rate) { build(:rate, amount_cents: 1000, currency: 'USD') }

    it 'monetizes amount_cents correctly' do
      expect(rate.amount).to be_a(Money)
      expect(rate.amount.cents).to eq(1000)
      expect(rate.amount.currency).to eq(Money::Currency.new('USD'))
    end

    it 'sets amount using Money object' do
      rate.amount = Money.new(2000, 'EUR')
      expect(rate.amount_cents).to eq(2000)
      expect(rate.currency).to eq('EUR')
    end

    it 'sets amount using string' do
      rate.amount = '15.50'
      expect(rate.amount_cents).to eq(1550)
    end

    it 'sets amount using decimal' do
      rate.amount = BigDecimal('25.75')
      expect(rate.amount_cents).to eq(2575)
    end
  end

  describe 'factory' do
    it 'creates valid rate with default values' do
      rate = build(:rate)
      expect(rate).to be_valid
      expect(rate.amount_cents).to eq(1)
      expect(rate.currency).to eq('USD')
    end

    it 'creates rate with custom values' do
      rate = build(:rate, amount_cents: 5000, currency: 'EUR')
      expect(rate).to be_valid
      expect(rate.amount_cents).to eq(5000)
      expect(rate.currency).to eq('EUR')
    end
  end

  describe 'real data integration' do
    before do
      # Create a sailing first
      sailing = create(:sailing, sailing_code: 'QRST')

      # Create rate from response.json data
      create(:rate,
        sailing: sailing,
        amount_cents: 76196, # 761.96 EUR * 100
        currency: 'EUR'
      )
    end

    it 'can load and query real rate data' do
      expect(Rate.count).to eq(1)
      rate = Rate.first
      expect(rate.amount).to eq(Money.new(76196, 'EUR'))
      expect(rate.amount.format).to eq('€761.96')
    end

    it 'validates amount is greater than zero' do
      rate = build(:rate, amount_cents: 0)
      expect(rate).not_to be_valid
      expect(rate.errors[:amount_cents]).to include('must be greater than 0')
    end

    it 'validates amount is greater than zero for negative values' do
      rate = build(:rate, amount_cents: -100)
      expect(rate).not_to be_valid
      expect(rate.errors[:amount_cents]).to include('must be greater than 0')
    end
  end

  describe 'currency handling' do
    it 'accepts valid 3-letter currency codes' do
      valid_currencies = [ 'USD', 'EUR', 'JPY', 'GBP', 'CAD' ]
      valid_currencies.each do |currency|
        rate = build(:rate, currency: currency)
        expect(rate).to be_valid
      end
    end

    it 'handles currency case sensitivity' do
      rate = build(:rate, currency: 'usd')
      expect(rate).to be_valid
      expect(rate.currency).to eq('usd')
    end
  end

  describe 'unique sailing constraint' do
    let(:sailing) { create(:sailing) }

    it 'allows one rate per sailing' do
      create(:rate, sailing: sailing)
      expect { create(:rate, sailing: sailing) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows different rates for different sailings' do
      sailing1 = create(:sailing)
      sailing2 = create(:sailing)

      rate1 = create(:rate, sailing: sailing1)
      rate2 = create(:rate, sailing: sailing2)

      expect(rate1).to be_persisted
      expect(rate2).to be_persisted
    end
  end
end
