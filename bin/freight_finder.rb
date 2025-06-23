# bin/freight_finder.rb
require_relative '../config/environment'
require 'pry-byebug' if Rails.env.development?

class InvalidInputError < StandardError; end

class FreightFinderCLI
  def run
    load_sample_data

    puts "Please enter origin port, destination port and criteria, each separated by a newline(press enter after each input)"

    # Read three lines of input safely
    origin_port = read_and_validate_port("origin port")
    destination_port = read_and_validate_port("destination port")
    criteria = read_input("criteria")

    # Debug breakpoint if needed
    binding.pry if ENV['DEBUG']

    routes = RouteFinderService.new.find_route(origin_port, destination_port, criteria)
    puts JSON.pretty_generate(routes)
  rescue EOFError
    STDERR.puts "Error: Need 3 input lines"
    exit 1
  rescue => e
    binding.pry if ENV['DEBUG']
    STDERR.puts "Error: #{e.message}"
    exit 1
  end

  private

  def read_and_validate_port(port_type)
    port = read_input(port_type)

    unless valid_port?(port)
      available_ports = get_available_ports.join(", ")
      raise InvalidInputError,
        "Invalid #{port_type} '#{port}'. Available ports: #{available_ports}"
    end

    port
  end

  def valid_port?(port_code)
    get_available_ports.include?(port_code)
  end

  def get_available_ports
    @available_ports ||= begin
      origin_ports = Sailing.distinct.pluck(:origin_port)
      destination_ports = Sailing.distinct.pluck(:destination_port)
      (origin_ports + destination_ports).uniq.sort
    end
  end


  def read_input(name)
    line = STDIN.gets
    raise EOFError if line.nil?

    result = line.chomp.strip
    result = result.upcase if name != "criteria"
    result = result.downcase if name == "criteria"
    result
  end

  def data_repository
    @data_repository ||= DataRepository.new
  end

  def load_sample_data
    return if Sailing.exists?

    json_file_path = Rails.root.join('db', 'response.json')
    ensure_shipping_data_exists(json_file_path)
    load_shipping_data_from_file(json_file_path)
  end

  def ensure_shipping_data_exists(file_path)
    return if File.exist?(file_path)

    raise StandardError, "Shipping data file not found at #{file_path}. " \
                        "Please ensure the freight forwarding data is available " \
                        "to calculate optimal shipping routes."
  end

  def load_shipping_data_from_file(file_path)
    json_data = File.read(file_path)
    data_repository.load_from_json(json_data)
  rescue JSON::ParserError => e
    raise StandardError, "Invalid shipping data format: #{e.message}"
  rescue => e
    raise StandardError, "Failed to load shipping data: #{e.message}"
  end
end

# Run CLI when file executed directly
if __FILE__ == $0
  FreightFinderCLI.new.run
end
