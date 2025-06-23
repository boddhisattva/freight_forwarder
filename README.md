# Freight Forwarder

## About

A Ruby on Rails application for finding optimal shipping routes between ports using different strategies (cheapest, fastest, cheapest-direct).

* For Cheapest: It makes use of Bellman Ford Algorithm

* For Fastest: It makes use of Dijkstra's Algorithm

One can find the detailed problem statement [here](https://github.com/boddhisattva/freight_forwarder/blob/main/problem_statement.md)

## Usage

### Setup with Docker

1. Make sure you have Docker running locally

2. **Make scripts executable:**
   ```bash
   chmod +x entrypoint.sh
   chmod +x setup_freight_finder.sh
   chmod +x setup_test.sh
   ```

3. **Clean rebuild:**
   ```bash
   docker-compose down
   docker system prune -f
   ./setup_freight_finder.sh
   ```

4. To run the app with Docker:

```
docker-compose run --rm freight_finder ruby bin/freight_finder.rb
```

### Running Tests with Docker

1. **Setup test environment:**
   ```bash
   ./setup_test.sh
   ```

2. **Run all tests:**
   ```bash
   docker-compose -f docker-compose.test.yml --profile test run --rm test
   ```

3. **Run specific test file(s):**
   ```bash
   # Models only
   docker-compose -f docker-compose.test.yml --profile test run --rm test bundle exec rspec spec/models/

   # Specific test file
   docker-compose -f docker-compose.test.yml --profile test run --rm test bundle exec rspec spec/models/sailing_spec.rb
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

```
ruby bin/freight_finder.rb
```

#### Running the tests
* Run from the project's root directory the `rspec` command

## Areas of Improvement: To Update(Kindly allow me some time to update this please)
* Error Handling and Reporting Improvements
  - Add Centralized error Handling for cases like Sailings without rates
  - Propagate  & clearly list insertion failures of Sailings & related data that are added through sources like `db/response.json`
* Bellman Ford Algorithm logic can be extended further to care of scenarios like discounts
* Record Insertion can be improved further to handle
  - bulk insert scenarios when we have a lot of data to import
  - proactively dealing with inconsistent data like Sailings without rates/exchange rates
*

## Design considerations: To Update(Kindly allow me some time to update this please)
* Bellman Ford Algorithm allows to take discounts etc., & hence it's better suited than Depth First Search for finding Cheapest Route
* Reachability Pruning used to get the Sailings Reachable

## Performance considerations: To Update(Kindly allow me some time to update this please)
* build_stubbed are used at various places for faster specs
* Indexes have also been added for faster DB lookups
