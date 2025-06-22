class DataRepository
  def initialize
    @sailing_repository = SailingRepository.new
    @exchange_rate_repository = ExchangeRateRepository.new
  end

  def load_from_json(json_data)
    parsed_data = JSON.parse(json_data)

    ActiveRecord::Base.transaction do
      load_exchange_rates(parsed_data["exchange_rates"])
      load_sailings_and_rates(parsed_data["sailings"], parsed_data["rates"])
    end
  end

  def find_direct_sailings(origin_port, destination_port)
    @sailing_repository.find_direct_sailings(origin_port, destination_port)
  end

  private

  attr_reader :sailing_repository, :exchange_rate_repository

  def load_exchange_rates(rates_data)
    exchange_rate_repository.load_rates_incrementally(rates_data)
  end

  def load_sailings_and_rates(sailings_data, rates_data)
    rates_hash = index_rates_by_sailing_code(rates_data)

    sailings_data.each do |sailing_data|
      rate_data = rates_hash[sailing_data["sailing_code"]]
      sailing_repository.find_or_create_sailing_with_rate(sailing_data, rate_data)
    end
  end

  def index_rates_by_sailing_code(rates_data)
    rates_data.index_by { |rate| rate["sailing_code"] }
  end
end
