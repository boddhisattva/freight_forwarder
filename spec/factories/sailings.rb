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
FactoryBot.define do
  factory :sailing do
    origin_port { "MyString" }
    destination_port { "MyString" }
    departure_date { "2025-06-14 18:01:20" }
    arrival_date { "2025-06-16 18:01:20" }
    sequence(:sailing_code) { |n| "TEST#{n}" }
  end
end
