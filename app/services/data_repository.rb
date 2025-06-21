class DataRepository # TODO:this is the repository pattern refactor to simplify further with SailingRepository under repository folder
  def load_from_json(json_data)
    parsed_data = JSON.parse(json_data)

    ActiveRecord::Base.transaction do
      load_exchange_rates_incrementally(parsed_data["exchange_rates"])
      load_sailings_and_rates_incrementally(parsed_data["sailings"], parsed_data["rates"])
    end
  end

  def find_direct_sailings(origin, destination)
    Sailing.direct(origin, destination)
        .includes(:rate)
  end

  private

  def load_exchange_rates_incrementally(rates_data)
    rates_data.each do |date, currencies|
      currencies.each do |currency, rate|
        ExchangeRate.find_or_create_by(
          departure_date: Date.parse(date),
          currency: currency
        ) do |exchange_rate|
          exchange_rate.rate = rate
        end
      end
    end
  end

  def load_sailings_and_rates_incrementally(sailings_data, rates_data)
    rates_hash = rates_data.index_by { |r| r["sailing_code"] }

    sailings_data.each do |sailing_data|
      sailing = Sailing.find_or_create_by(
        sailing_code: sailing_data["sailing_code"]
      ) do |s|
        s.origin_port = sailing_data["origin_port"]
        s.destination_port = sailing_data["destination_port"]
        s.departure_date = Date.parse(sailing_data["departure_date"])
        s.arrival_date = Date.parse(sailing_data["arrival_date"])
      end

      rate_data = rates_hash[sailing.sailing_code]
      if rate_data
        Rate.find_or_create_by(sailing: sailing) do |rate|
          rate.amount = Money.new(
            (rate_data["rate"].to_f * 100).round,
            rate_data["rate_currency"]
          )
          rate.currency = rate_data["rate_currency"]
        end
      end
    end
  end
end
