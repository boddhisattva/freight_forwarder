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
FactoryBot.define do
  factory :rate do
    sailing { create(:sailing) }
    amount_cents { 1 }
    currency { "USD" }
  end
end
