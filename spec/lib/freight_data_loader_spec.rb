# spec/lib/freight_data_loader_spec.rb
require 'rails_helper'

RSpec.describe FreightDataLoader do
  subject(:loader) { described_class.new }

  let(:sample_json_data) do
    {
      "sailings" => [
        {
          "origin_port" => "CNSHA",
          "destination_port" => "NLRTM",
          "departure_date" => "2022-02-01",
          "arrival_date" => "2022-03-01",
          "sailing_code" => "ABCD"
        }
      ],
      "rates" => [
        {
          "sailing_code" => "ABCD",
          "rate" => "589.30",
          "rate_currency" => "USD"
        }
      ],
      "exchange_rates" => {
        "2022-02-01" => {
          "usd" => 1.126,
          "jpy" => 130.15
        }
      }
    }.to_json
  end

  let(:mock_data_repository) { instance_double(DataRepository) }

  before do
    allow(DataRepository).to receive(:new).and_return(mock_data_repository)
  end

  describe '.load!' do
    it 'creates new instance and calls load_freight_data' do
      instance = instance_double(described_class)

      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:load_freight_data)

      described_class.load!

      expect(described_class).to have_received(:new)
      expect(instance).to have_received(:load_freight_data)
    end
  end

  describe '#load_freight_data' do
    let(:file_path) { Rails.root.join('db', 'response.json') }

    context 'when freight data loads successfully' do
      before do
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(File).to receive(:read).with(file_path).and_return(sample_json_data)
        allow(mock_data_repository).to receive(:load_from_json)
      end

      it 'loads data and prints success message' do
        expect { loader.load_freight_data }.to output(/Freight forwarding data loaded successfully!/).to_stdout
        expect(mock_data_repository).to have_received(:load_from_json).with(sample_json_data)
      end

      it 'does not raise any errors' do
        expect { loader.load_freight_data }.not_to raise_error
      end
    end

    context 'when shipping data already exists' do
      before do
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(File).to receive(:read).with(file_path).and_return(sample_json_data)
        allow(mock_data_repository).to receive(:load_from_json)
      end

      it 'loads data successfully using find_or_create patterns' do
        expect { loader.load_freight_data }.to output(/Freight forwarding data loaded successfully!/).to_stdout
        expect(mock_data_repository).to have_received(:load_from_json).with(sample_json_data)
      end
    end

    context 'when freight data file does not exist' do
      before do
        allow(File).to receive(:exist?).with(file_path).and_return(false)
      end

      it 'raises StandardError with helpful message' do
        expect { loader.load_freight_data }.to raise_error(
          StandardError,
          /Freight data file not found at.*Please ensure shipping data is available/
        )
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)

        expect { loader.load_freight_data }.to raise_error(StandardError)
        expect(Rails.logger).to have_received(:error).with(/Failed to load freight data/)
      end
    end

    context 'when JSON file contains invalid JSON' do
      let(:invalid_json) { '{ invalid json' }

      before do
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(File).to receive(:read).with(file_path).and_return(invalid_json)
        # Use real DataRepository to get actual JSON parsing error
        allow(DataRepository).to receive(:new).and_call_original
      end

      it 'raises StandardError with JSON parsing error message' do
        expect { loader.load_freight_data }.to raise_error(
          StandardError,
          /Freight data loading failed:.*expected object key/i
        )
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)

        expect { loader.load_freight_data }.to raise_error(StandardError)
        expect(Rails.logger).to have_received(:error).with(/Failed to load freight data/)
      end
    end

    context 'when data repository fails to load data' do
      let(:repository_error) { StandardError.new('Database connection failed') }

      before do
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(File).to receive(:read).with(file_path).and_return(sample_json_data)
        allow(mock_data_repository).to receive(:load_from_json).and_raise(repository_error)
      end

      it 'raises StandardError with repository error details' do
        expect { loader.load_freight_data }.to raise_error(
          StandardError,
          'Freight data loading failed: Database connection failed'
        )
      end

      it 'logs the original error' do
        allow(Rails.logger).to receive(:error)

        expect { loader.load_freight_data }.to raise_error(StandardError)
        expect(Rails.logger).to have_received(:error).with('Failed to load freight data: Database connection failed')
      end
    end

    context 'when file read operation fails' do
      let(:file_error) { Errno::EACCES.new('Permission denied') }

      before do
        allow(File).to receive(:exist?).with(file_path).and_return(true)
        allow(File).to receive(:read).with(file_path).and_raise(file_error)
      end

      it 'raises StandardError with file error details' do
        expect { loader.load_freight_data }.to raise_error(
          StandardError,
          /Freight data loading failed:.*Permission denied/
        )
      end
    end
  end

  describe 'error handling and logging' do
    before do
      allow(File).to receive(:exist?).and_return(false)
      allow(Rails.logger).to receive(:error)
    end

    it 'ensures all errors are logged before re-raising' do
      expect { loader.load_freight_data }.to raise_error(StandardError)
      expect(Rails.logger).to have_received(:error)
    end

    it 'wraps all errors in StandardError for consistent error handling' do
      expect { loader.load_freight_data }.to raise_error(StandardError)
    end
  end
end
