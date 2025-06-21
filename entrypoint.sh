#!/bin/bash
set -e

# Wait for database
echo "Waiting for database..."
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -d postgres -c "\q" 2>/dev/null; do
  echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Postgres is up - executing command"

# Ensure we're in the right directory
cd /app

# Create and migrate database
bundle exec rails db:create db:migrate 2>/dev/null || echo "Database already exists"

# Execute the passed command
exec "$@"
