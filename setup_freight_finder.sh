#!/bin/bash

# Setup script for Freight Forwarder CLI
set -e

echo "🚢 Your Freight Forwarder CLI with sample data is being setup. Please allow for a few minutes."
echo "=============================================="



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
