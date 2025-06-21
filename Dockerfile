# Use official Ruby 3.4.4 image
FROM ruby:3.4.4-slim

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    nodejs \
    npm \
    git \
    curl \
    libyaml-dev \
    libffi-dev \
    libssl-dev \
    zlib1g-dev && \
    npm install -g yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && \
    bundle install

# Copy package.json and install JS dependencies
COPY package*.json ./
RUN yarn install 2>/dev/null || true

# Copy application code
COPY . .

# Set up scripts
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && \
    chmod +x bin/freight_finder.rb

# Precompile assets
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=dummy_key_for_build_only
RUN bundle exec rails assets:precompile

# Reset environment
ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_LOG_TO_STDOUT=true

# Expose port
EXPOSE 3000

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
