#!/bin/bash

# Setup script for running tests with Docker (with authentication - Option 1 best practice)
set -e

echo "🧪 Setting up Docker test environment (with authentication)..."
echo "=============================================="

# Start database service
echo "🐳 Starting database service..."
docker-compose -f docker-compose.test.yml up -d db

# Wait for database
echo "⏳ Waiting for database to be ready..."
sleep 5
until docker-compose -f docker-compose.test.yml exec -T db pg_isready -U freight_user -d freight_forwarder_test; do
  echo "Database not ready, waiting..."
  sleep 2
done

# Create test database and run migrations
echo "🔨 Setting up test database..."
docker-compose -f docker-compose.test.yml run --rm test bundle exec rails db:create db:migrate RAILS_ENV=test

echo ""
echo "🎉 Test environment setup completed (with authentication)!"
echo ""
echo "🧪 To run all tests:"
echo "docker-compose -f docker-compose.test.yml --profile test run --rm test"
echo ""
echo "🧪 To run specific test files:"
echo "docker-compose -f docker-compose.test.yml --profile test run --rm test bundle exec rspec spec/models/"
echo "docker-compose -f docker-compose.test.yml --profile test run --rm test bundle exec rspec spec/repositories/"
echo "docker-compose -f docker-compose.test.yml --profile test run --rm test bundle exec rspec spec/services/"
echo ""
echo "🧪 To run tests with specific options:"
echo "docker-compose -f docker-compose.test.yml --profile test run --rm test bundle exec rspec --format documentation"
echo ""
echo "To stop services:"
echo "docker-compose -f docker-compose.test.yml down"
