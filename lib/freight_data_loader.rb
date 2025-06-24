# lib/freight_data_loader.rb
class FreightDataLoader
  def self.load!
    new.load_freight_data
  end

  def load_freight_data
    load_from_json_file
    puts "Freight forwarding data loaded successfully!"
  rescue => e
    Rails.logger.error "Failed to load freight data: #{e.message}"
    raise StandardError, "Freight data loading failed: #{e.message}"
  end

  private

  def load_from_json_file
    json_data = read_freight_data_file
    data_repository.load_from_json(json_data)
  end

  def read_freight_data_file
    file_path = freight_data_file_path
    ensure_freight_file_exists(file_path)
    File.read(file_path)
  rescue JSON::ParserError => e
    raise StandardError, "Invalid freight data format: #{e.message}"
  end

  def freight_data_file_path
    Rails.root.join('db', 'response.json')
  end

  def ensure_freight_file_exists(file_path)
    return if File.exist?(file_path)

    raise StandardError, "Freight data file not found at #{file_path}. " \
                        "Please ensure shipping data is available."
  end

  def data_repository
    @data_repository ||= DataRepository.new
  end
end
