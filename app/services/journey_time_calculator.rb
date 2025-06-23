class JourneyTimeCalculator < JourneyCalculator
  def calculate_total_time(previous_ship_arrival, current_ship_departure, current_ship_arrival)
    # Direct sailing (no previous connection): just the sailing time
    return sailing_duration(current_ship_departure, current_ship_arrival) if previous_ship_arrival.nil?

    # Multi-leg journey: waiting time + sailing time
    port_layover_time(previous_ship_arrival, current_ship_departure) +
      sailing_duration(current_ship_departure, current_ship_arrival)
  end

  private

  def port_layover_time(ship_arrival, next_ship_departure)
    waiting_days = (next_ship_departure.to_date - ship_arrival.to_date).to_i
    [ 0, waiting_days ].max  # Can't have negative waiting time!
  end

  def sailing_duration(departure_date, arrival_date)
    (arrival_date.to_date - departure_date.to_date).to_i
  end
end
