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
class Rate < ApplicationRecord
  belongs_to :sailing

  monetize :amount_cents, with_model_currency: :currency

  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
end
