
class JourneyTimeCalculator
  def calculate_total_time(previous_ship_arrival, current_ship_departure, current_ship_arrival)
    # Direct sailing (no previous connection): just the sailing time
    return sailing_duration(current_ship_departure, current_ship_arrival) if previous_ship_arrival.nil?

    # Multi-leg journey: waiting time + sailing time
    port_layover_time(previous_ship_arrival, current_ship_departure) +
      sailing_duration(current_ship_departure, current_ship_arrival)
  end

  # Check if we can actually make this shipping connection
  def valid_connection?(previous_sailing, current_sailing)
    # First ship of journey: always valid
    return true unless previous_sailing

    # Must arrive before next ship departs (basic freight forwarding logic)
    current_sailing.departure_date >= previous_sailing.arrival_date
  end

  private

  def port_layover_time(ship_arrival, next_ship_departure)
    waiting_days = (next_ship_departure - ship_arrival).to_i
    [ 0, waiting_days ].max  # Can't have negative waiting time!
  end

  def sailing_duration(departure_date, arrival_date)
    (arrival_date - departure_date).to_i
  end
end
