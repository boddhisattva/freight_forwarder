# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SailingRepository do
  subject(:repository) { described_class.new }

  describe '#find_direct_sailings' do
    let(:origin_port) { 'CNSHA' }
    let(:destination_port) { 'NLRTM' }

    context 'when direct sailings exist' do
      before do
        # Create sailings with rates
        @sailing1 = create(:sailing,
          origin_port: origin_port,
          destination_port: destination_port,
          sailing_code: 'ABC123'
        )
        @sailing2 = create(:sailing,
          origin_port: origin_port,
          destination_port: destination_port,
          sailing_code: 'DEF456'
        )

        # Create rates for the sailings
        create(:rate, sailing: @sailing1, amount: Money.new(50000, 'USD'))
        create(:rate, sailing: @sailing2, amount: Money.new(60000, 'EUR'))

        # Create unrelated sailing (different route)
        @other_sailing = create(:sailing,
          origin_port: 'ESBCN',
          destination_port: 'BRSSZ'
        )
      end

      it 'returns direct sailings between specified ports' do
        result = repository.find_direct_sailings(origin_port, destination_port)

        expect(result).to contain_exactly(@sailing1, @sailing2)
      end

      it 'includes rates in the query to avoid N+1' do
        expect(Sailing).to receive(:direct).with(origin_port, destination_port)
                             .and_call_original
        expect_any_instance_of(ActiveRecord::Relation).to receive(:includes).with(:rate)
                                                            .and_call_original

        repository.find_direct_sailings(origin_port, destination_port)
      end

      it 'does not return sailings from different routes' do
        result = repository.find_direct_sailings(origin_port, destination_port)

        expect(result).not_to include(@other_sailing)
      end
    end

    context 'when no direct sailings exist' do
      it 'returns empty collection' do
        result = repository.find_direct_sailings(origin_port, destination_port)

        expect(result).to be_empty
      end
    end
  end

  describe '#find_or_create_sailing_with_rate' do
    let(:sailing_data) do
      {
        'sailing_code' => 'TEST123',
        'origin_port' => 'CNSHA',
        'destination_port' => 'NLRTM',
        'departure_date' => '2024-01-15',
        'arrival_date' => '2024-02-15'
      }
    end

    let(:rate_data) do
      {
        'rate' => '500.50',
        'rate_currency' => 'USD'
      }
    end

    context 'when sailing and rate do not exist' do
      it 'creates new sailing with rate' do
        expect {
          repository.find_or_create_sailing_with_rate(sailing_data, rate_data)
        }.to change { Sailing.count }.by(1)
          .and change { Rate.count }.by(1)
      end

      it 'creates sailing with correct attributes' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, rate_data)

        expect(sailing).to have_attributes(
          sailing_code: 'TEST123',
          origin_port: 'CNSHA',
          destination_port: 'NLRTM',
          departure_date: Date.new(2024, 1, 15),
          arrival_date: Date.new(2024, 2, 15)
        )
      end

      it 'creates rate with correct money object and currency' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, rate_data)
        rate = sailing.rate

        expect(rate.amount).to eq(Money.new(50050, 'USD'))
        expect(rate.currency).to eq('USD')
      end
    end

    context 'when sailing already exists' do
      before do
        @existing_sailing = create(:sailing, sailing_code: 'TEST123')
      end

      it 'does not create duplicate sailing' do
        expect {
          repository.find_or_create_sailing_with_rate(sailing_data, rate_data)
        }.not_to change { Sailing.count }
      end

      it 'returns existing sailing' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, rate_data)

        expect(sailing).to eq(@existing_sailing)
      end

      it 'creates rate for existing sailing if none exists' do
        expect {
          repository.find_or_create_sailing_with_rate(sailing_data, rate_data)
        }.to change { Rate.count }.by(1)
      end
    end

    context 'when rate already exists for sailing' do
      before do
        @sailing = create(:sailing, sailing_code: 'TEST123')
        @existing_rate = create(:rate, sailing: @sailing)
      end

      it 'does not create duplicate rate' do
        expect {
          repository.find_or_create_sailing_with_rate(sailing_data, rate_data)
        }.not_to change { Rate.count }
      end
    end

    context 'when rate_data is nil' do
      it 'creates sailing without rate' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, nil)

        expect(sailing).to be_persisted
        expect(sailing.rate).to be_nil
      end

      it 'does not create any rate record' do
        expect {
          repository.find_or_create_sailing_with_rate(sailing_data, nil)
        }.not_to change { Rate.count }
      end
    end

    context 'when sailing_data has invalid date format' do
      let(:invalid_sailing_data) do
        sailing_data.merge('departure_date' => 'invalid-date')
      end

      it 'raises ArgumentError for invalid date' do
        expect {
          repository.find_or_create_sailing_with_rate(invalid_sailing_data, rate_data)
        }.to raise_error(Date::Error)
      end
    end

    context 'when sailing_data is missing required fields' do
      let(:incomplete_sailing_data) do
        { 'sailing_code' => 'TEST123' }
      end

      it 'raises TypeError when trying to parse nil date' do
        expect {
          repository.find_or_create_sailing_with_rate(incomplete_sailing_data, rate_data)
        }.to raise_error(TypeError, /no implicit conversion of nil into String/)
      end
    end

    context 'when rate data has invalid amount' do
      let(:invalid_rate_data) do
        {
          'rate' => 'not-a-number',
          'rate_currency' => 'USD'
        }
      end

      it 'raises validation error for invalid rate amount' do
        expect {
          repository.find_or_create_sailing_with_rate(sailing_data, invalid_rate_data)
        }.to raise_error(ActiveRecord::RecordInvalid, /Amount cents must be greater than 0/)
      end
    end

    context 'when handling different currencies' do
      let(:eur_rate_data) do
        {
          'rate' => '123.45',
          'rate_currency' => 'EUR'
        }
      end

      it 'creates money object with correct currency' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, eur_rate_data)
        rate = sailing.rate

        expect(rate.amount).to eq(Money.new(12345, 'EUR'))
        expect(rate.currency).to eq('EUR')
      end
    end

    context 'when handling large decimal amounts' do
      let(:large_amount_rate_data) do
        {
          'rate' => '999999.99',
          'rate_currency' => 'USD'
        }
      end

      it 'correctly converts large amounts to money object' do
        sailing = repository.find_or_create_sailing_with_rate(sailing_data, large_amount_rate_data)
        rate = sailing.rate

        expect(rate.amount).to eq(Money.new(99999999, 'USD'))
      end
    end
  end
end
