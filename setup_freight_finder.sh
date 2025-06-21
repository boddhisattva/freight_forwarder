#!/bin/bash

# Test script for Freight Finder CLI
set -e

echo "🚢 Testing Freight Finder CLI with Sample Data"
echo "=============================================="

# Function to test CLI with input (commented out for later use)
# test_cli() {
#     local test_name="$1"
#     local origin="$2"
#     local destination="$3"
#     local criteria="$4"

#     echo ""
#     echo "🧪 Testing: $test_name"
#     echo "Input: $origin -> $destination ($criteria)"
#     echo "Response:"

#     # Create input file
#     echo -e "$origin\n$destination\n$criteria" > /tmp/test_input.txt

#     # Run the CLI
#     docker-compose run --rm -T freight_finder ruby bin/freight_finder.rb < /tmp/test_input.txt

#     echo "✅ Test completed"
# }

# Start services
echo "🐳 Starting Docker services..."
docker-compose up -d db

# Wait for database
echo "⏳ Waiting for database to be ready..."
sleep 10  # Give database time to start
until docker-compose exec -T db pg_isready -U freight_user -d freight_forwarder_production; do
  echo "Database not ready, waiting..."
  sleep 2
done

# Build and start the app
echo "🔨 Building application with new Docker setup..."
docker-compose build freight_finder --no-cache
docker-compose run --rm freight_finder bundle exec rails db:create db:migrate

echo "📊 Loading sample data..."
docker-compose run --rm freight_finder ruby -e "
require_relative 'config/environment'
require_relative 'bin/freight_finder'
FreightFinderCLI.new.send(:load_sample_data)
puts 'Sample data loaded successfully!'
"

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "🚢 To use the freight finder with stdin/stdout:"
echo "echo -e 'CNSHA\\nNLRTM\\ncheapest-direct' | docker-compose run --rm -T freight_finder ruby bin/freight_finder.rb"
echo ""
echo "Or run interactively:"
echo "docker-compose run --rm freight_finder ruby bin/freight_finder.rb"
echo ""
echo "To stop services:"
echo "docker-compose down"

# Commented out test cases for later use
# Test cases from problem statement
# test_cli "Cheapest Direct Route" "CNSHA" "NLRTM" "cheapest-direct"
# test_cli "Cheapest Route (Any)" "CNSHA" "NLRTM" "cheapest"
# test_cli "Fastest Route" "CNSHA" "NLRTM" "fastest"

# Additional test cases
# test_cli "Alternative Route Test" "CNSHA" "ESBCN" "cheapest-direct"
