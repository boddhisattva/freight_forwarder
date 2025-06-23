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
    it { should validate_presence_of(:currency) }

    it 'validates amount_cents is greater than zero' do
      expect(build(:rate, amount_cents: 1)).to be_valid
      expect(build(:rate, amount_cents: 5000)).to be_valid

      expect(build(:rate, amount_cents: 0)).not_to be_valid
      expect(build(:rate, amount_cents: -100)).not_to be_valid
    end
  end
end
