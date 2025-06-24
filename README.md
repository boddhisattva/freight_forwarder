# Freight Forwarder

## About

A Ruby on Rails application for finding optimal shipping routes between ports using different strategies (cheapest, fastest, cheapest-direct).

* For Cheapest: It makes use of Bellman Ford Algorithm

* For Fastest: It makes use of Dijkstra's Algorithm

One can find the detailed problem statement [here](https://github.com/boddhisattva/freight_forwarder/blob/main/problem_statement.md)

## Usage

### Run Freight Forwarder app in CLI mode with Docker

1. **Make sure you have Docker app running locally**

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

**Please note**: `./setup_freight_finder.sh` also runs `rails db:seed` to load data present in `db/response.json`

4. **To run the app with Docker:**

```
docker-compose run --rm -T -e RAILS_ENV=development freight_finder ruby bin/freight_finder.rb
```

A small side note for one's kind notice: In containerized environments(and many other places in life), explicit is always better than implicit, hence explicitly specifying `RAILS_ENV=development` above.

**Please note**:
1. `MAX_HOPS` represents the the maximum number of stops (or 'hops') allowed between the origin and destination ports
  - `MAX_HOPS` currently defaults to a value of 4 & is made configurable through below ways:
    - For production deployments `MAX_HOPS` can be set via an environment variable. This updates `config.max_hops` in `config/application.rb` and it requires redeploy/restart of server to take an updated value.
    - When using Docker `MAX_HOPS`, one can update this via
      - `docker-compose.yml`
      - `docker-compose.test.yml`

### Running Tests with Docker

1. **Setup test environment:**
   ```bash
   ./setup_test.sh
   ```

2. **Run all tests:**
   ```bash
   docker-compose -f docker-compose.test.yml --profile test run --rm -e RAILS_ENV=test test
   ```

3. **Run specific test file(s):**
   ```bash
   # Models only
   docker-compose -f docker-compose.test.yml --profile test run --rm -e RAILS_ENV=test test bundle exec rspec spec/models/

   # Specific test file
   docker-compose -f docker-compose.test.yml --profile test run --rm -e RAILS_ENV=test test bundle exec rspec spec/models/sailing_spec.rb
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
* Please run `rake db:seed` to load freight data available in `db/response.json`

#### Running the Rails app in CLI mode with

```
ruby bin/freight_finder.rb
```

#### Running the tests
* Run from the project's root directory the `rspec` command

## Areas of Improvement:
* Error Handling and Reporting Improvements
  - Add Centralized error Handling for cases like Sailings without rates
  - Propagate  & clearly list insertion failures of Sailings & related data that are added through sources like `db/response.json`
* Bellman Ford Algorithm logic can be extended further to care of scenarios like discounts
* Record Insertion can be improved further to
  - handle bulk insert scenarios when we have a lot of data to import
  - proactively deal with inconsistent data like Sailings without rates/exchange rates
* Exchange Rates can be cached in advance
* Improve priority queue implementation by replacing Array with Min Heap implementation

## Design considerations:
* Bellman Ford Algorithm allows to take discounts etc., & hence it's better suited than Depth First Search for finding Cheapest Route
* Adherance to SOLID principles, proactively using smaller classes for more object oriented code
* Using a Repository pattern(with relevant directory structure) and Template Method Pattern as appropriate for various entities as needed
* Actively used Composition for various classes where applicable
* Money Related operations and handlng made easier by storing values as cents(Credits: Money Rails Gem is very helpful here)


## Performance considerations:
* Reachability Pruning(via `PortConnectivityFilter`) used to get required Sailings based on origin & destination port instead of having to load all Sailings
* `build_stubbed` is used at various places for faster specs
* Indexes have also been added for faster DB lookups

## Other Considerations
* Code comments have been added selectively to attempt to explain more challenging parts for ease of understanding for future developers enhancing & maintaining the app
