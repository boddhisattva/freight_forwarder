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
class Sailing < ApplicationRecord
  has_one :rate, dependent: :destroy

  validates :sailing_code, presence: true, uniqueness: true
  validates :origin_port, :destination_port, presence: true
  validates :departure_date, :arrival_date, presence: true
  validate :arrival_after_departure

  scope :from_port, ->(port) { where(origin_port: port) }
  scope :to_port, ->(port) { where(destination_port: port) }
  scope :direct, ->(origin, destination) { from_port(origin).to_port(destination) }

  def duration_days
    ((arrival_date - departure_date) / 1.day).ceil
  end

  def as_route_hash
    {
      origin_port: origin_port,
      destination_port: destination_port,
      departure_date: departure_date.strftime("%Y-%m-%d"),
      arrival_date: arrival_date.strftime("%Y-%m-%d"),
      sailing_code: sailing_code,
      rate: rate ? sprintf("%.2f", rate.amount.to_f) : nil,
      rate_currency: rate ? rate.currency : nil
    }
  end

  private

  def arrival_after_departure
    return unless departure_date && arrival_date

    errors.add(:arrival_date, "must be after departure date") if arrival_date <= departure_date
  end
end
