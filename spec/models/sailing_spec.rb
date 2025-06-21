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
  pending "add some examples to (or delete) #{__FILE__}"
end
