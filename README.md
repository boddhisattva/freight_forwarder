# Freight Forwarder

## About

A Ruby on Rails application for finding optimal shipping routes between ports using different strategies (cheapest, fastest, cheapest-direct).
For Cheapest: It makes use of Bellman Ford Algorithm
For Fastest: It makes use of Dijkstra's Algorithm

## Usage

### Setup with Docker

1. Make sure you have Docker running locally

2. **Make scripts executable:**
   ```bash
   chmod +x entrypoint.sh
   chmod +x test_freight_finder.sh
   ```

3. **Clean rebuild:**
   ```bash
   docker-compose down
   docker system prune -f
   docker-compose build --no-cache
   ```

4. **Run the application:**
   ```bash
   docker-compose up
   ```

5. **Run tests:**
   ```bash
   ./test_freight_finder.sh
   ```

6. To run the app with Docker:

```
docker-compose run --rm freight_finder ruby bin/freight_finder.rb
```

### Local Development Setup

### Dependencies
* Ruby 3.4.4, Rails 8.0.2, Postgres DB v16
* Please refer to the Gemfile for the other dependencies

### Basic App Setup
------

#### Installing app dependencies

* Run `bundle install` from a project's root directory

#### Setting up the Database schema
* Run from the project root directory: `rake db:create` and `rake db:migrate`

#### Data Setup
* The application uses real shipping data stored in `db/response.json` . This is auto loaded when you run the below code command in next step

#### Running the Rails app in CLI mode with

ruby bin/freight_finder.rb

* Start the rails app with: `rails s`

#### Running the tests
* Run from the project's root directory the `rspec` command

# Areas of Improvement: To Update

# Design considerations: To Update
