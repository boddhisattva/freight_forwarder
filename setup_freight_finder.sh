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
until docker-compose exec -T db pg_isready -U freight_user -d freight_forwarder_development; do
  echo "Database not ready, waiting..."
  sleep 2
done

# Build and start the app
echo "🔨 Building application with new Docker setup..."
docker-compose build freight_finder --no-cache

# Create development database and run migrations
echo "🛠️ Setting up development database..."
docker-compose run --rm -e RAILS_ENV=development freight_finder bundle exec rails db:create db:migrate

# Load freight data using Rails seeds
echo "📊 Loading freight forwarding data..."
docker-compose run --rm -e RAILS_ENV=development freight_finder bundle exec rails db:seed

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "🚢 To use the freight finder with stdin/stdout:"
echo "echo -e 'CNSHA\\nNLRTM\\ncheapest-direct' | docker-compose run --rm -T -e RAILS_ENV=development freight_finder ruby bin/freight_finder.rb"
echo ""
echo "Or run interactively:"
echo "docker-compose run --rm -e RAILS_ENV=development freight_finder ruby bin/freight_finder.rb"
echo ""
echo "To stop services:"
echo "docker-compose down"
