class SailingRepository
  def find_direct_sailings(origin_port, destination_port)
    Sailing.direct(origin_port, destination_port)
           .includes(:rate)
  end

  def find_or_create_sailing_with_rate(sailing_data, rate_data)
    sailing = find_or_create_sailing(sailing_data)
    create_rate_for_sailing(sailing, rate_data) if rate_data
    sailing
  end

  private

  def find_or_create_sailing(sailing_data)
    Sailing.find_or_create_by(
      sailing_code: sailing_data["sailing_code"]
    ) do |sailing|
      sailing.origin_port = sailing_data["origin_port"]
      sailing.destination_port = sailing_data["destination_port"]
      sailing.departure_date = Date.parse(sailing_data["departure_date"])
      sailing.arrival_date = Date.parse(sailing_data["arrival_date"])
    end
  end

  def create_rate_for_sailing(sailing, rate_data)
    Rate.find_or_create_by(sailing: sailing) do |rate|
      rate.amount = convert_to_money_object(rate_data)
      rate.currency = rate_data["rate_currency"]
    end
  end

  def convert_to_money_object(rate_data)
    Money.new(
      (rate_data["rate"].to_f * 100).round,
      rate_data["rate_currency"]
    )
  end
end
