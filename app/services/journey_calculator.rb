class JourneyCalculator
  def valid_connection?(previous_sailing, current_sailing)
    # First ship of journey: always valid (nothing to connect from)
    return true unless previous_sailing

    # Basic freight forwarding rule: must arrive before next ship departs
    current_sailing.departure_date >= previous_sailing.arrival_date
  end
end
