## Background

Shypple is a freight forwarder company. That means we help other companies to
get their products from one place to another. We must deliver the goods as fast
as possible. To achieve that, we need to replace some human labor with
automation. We have part of the process being done via Excel and that is not
good to scale.

Have we told you we want to be the biggest freight forwarder company in the
world?

The good news is the team MapReduce (yeah, they choose this name) already
created a service that aggregates lots of information and returns a JSON file
for us. This MapReduce service returns all shipping options available in the
database. We have given you a sample JSON response from MapReduce service.

Your job is to create a small service that does some calculations using the
JSON file.

Exchange rates in the JSON file are based on EUR (For example 2022-01-29 usd
rate 1.1138 is USD/EUR rate). We decide which exchange_rate will be used to
calculate EUR sailing rate based on the *departure_date* of the sailing. Use
sailing_code from sailing & rate to get the rate amount & currency.

Your Product Owner created 3 tickets for you: 3rd task(TST-0003) is a nice to
have feature. So it is a bonus task & you can finish it if you have time.

The solution should include all configuration files needed to build and run in
a Docker container (don't expect anything else but Docker to be installed).

### Input/Output Specification
1. The first line is the origin_port code
2. The second line is the destination_port code
3. The third line is the criteria (cheapest-direct, cheapest, fastest)
5. The next lines you should print the result

#### Input
```json
CNSHA
NLRTM
cheapest-direct
```

#### Output
```json
[
  {
    "origin_port": "CNSHA",
    "destination_port": "NLRTM",
    "departure_date": "2024-02-01",
    "arrival_date": "2024-03-01",
    "sailing_code": "XXXX",
    "rate": "123.00",
    "rate_currency": "USD"
  }
]
```

#### (1) PLS-0001 - *Acceptance criteria*: Return the cheapest direct sailing between origin port & destination port in following format. For example using CNSHA as origin port & NLRTM as destination port input parameters


```json
CNSHA
NLRTM
cheapest-direct
[
  {
    "origin_port": "CNSHA",
    "destination_port": "NLRTM",
    "departure_date": "2024-02-01",
    "arrival_date": "2024-03-01",
    "sailing_code": "XXXX",
    "rate": "232.30",
    "rate_currency": "USD"
  }
]
```

#### (2) WRT-0002 - *Acceptance criteria*: Return the cheapest sailing (direct or indirect). If the cheapest one contains more than one sailing (two sailings) in the following format, you should return all sailing legs (You need to compare the sum of all sailing legs to find the cheapest sailing option). Use same CNSHA as origin port & NLRTM as destination port input parameters

#### Input
```json
CNSHA
NLRTM
cheapest
```

#### Output
```json
[
  {
    "origin_port": "CNSHA",
    "destination_port": "ESBCN",
    "departure_date": "2022-01-29",
    "arrival_date": "2022-02-06",
    "sailing_code": "ERXQ",
    "rate": "261.96",
    "rate_currency": "EUR"
  },
  {
    "origin_port": "ESBCN",
    "destination_port": "NLRTM",
    "departure_date": "2022-02-16",
    "arrival_date": "2022-02-20",
    "sailing_code": "ETRG",
    "rate": "69.96",
    "rate_currency": "USD"
  }
]
```

#### (3) TST-0003 - *Acceptance criteria*: Return the fastest sailing legs (direct or indirect) in the same above format
##### Definition of "fastest": the sailing leg(s) with the shortest total journey time between the origin and destination.

#### Input
```json
CNSHA
NLRTM
fastest
```

#### Output
```json
[
  {
    "origin_port": "CNSHA",
    "destination_port": "ESBCN",
    "departure_date": "2022-01-29",
    "arrival_date": "2022-02-06",
    "sailing_code": "ERXQ",
    "rate": "261.96",
    "rate_currency": "EUR"
  },
  {
    "origin_port": "ESBCN",
    "destination_port": "NLRTM",
    "departure_date": "2022-02-16",
    "arrival_date": "2022-02-20",
    "sailing_code": "ETRG",
    "rate": "69.96",
    "rate_currency": "USD"
  }
]
```

### Project Requirements

1. Please, create one single branch for all the changes.
2. Make sure your app run on docker and all the dependencies are included on it
3. Please send a zip file with the solution to this email address, j.souza@shypple.com, once you're done.
4. The solution must work with standard input and output (stdin and stdout).
5. For indirect routes, the solution should handle more than two legs.

You should provide a solution that make possible to scale because new requirements will come soon.

4. SLD-0004 - coming soon
5. DRY-0005 - coming soon
6. TDD-0006 - coming soon

We will evaluate the solution with some criteria:

1. Object Oriented Concepts
2. SOLID
3. DRY
4. Test Coverage

#### Lingo

CNSHA - Shanghai

NLRTM - Rotterdam

ESBCN - Barcelona

BRSSZ - Santos

Shipment Leg: A "shipment leg" refers to each segment of a shipment's journey
between two specific locations, such as from one port to another. For example,
if a shipment travels from Shanghai to Rotterdam with a stopover in Barcelona,
the journey consists of two legs: Shanghai to Barcelona and Barcelona to
Rotterdam.

#### We are here to help

Feel free to reach out to us with any questions or concerns you may have. We're
here to help and are more than happy to provide any clarification needed.

Good luck!

:q!
