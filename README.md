# SwissPairing

A Ruby gem that implements a FIDE-compliant Swiss pairing system for chess tournaments. This gem follows the official FIDE Swiss Rules with full support for ratings, titles, and color allocation rules.

## Features

- FIDE-compliant Swiss pairing system implementation
- Support for player ratings and official FIDE titles (GM, IM, WGM, FM, WIM, CM, WFM, WCM)
- Sophisticated color allocation following FIDE rules
- Proper handling of byes for odd numbers of players
- Prevention of rematches between players
- Tournament acceleration option for large events
- Complete tournament management with results tracking
- Comprehensive error handling and validation
- Full test coverage with RSpec

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'swisspairing'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install swisspairing
```

## Basic Usage

### Creating Players

```ruby
require 'swisspairing'

# Create players with ratings and optional FIDE titles
players = [
  Swisspairing::Player.new(name: "GM Smith", rating: 2500, title: "GM", id: 1),
  Swisspairing::Player.new(name: "IM Jones", rating: 2400, title: "IM", id: 2),
  Swisspairing::Player.new(name: "FM Brown", rating: 2300, title: "FM", id: 3),
  Swisspairing::Player.new(name: "Alice", rating: 2200, id: 4)
]
```

### Setting Up a Tournament

```ruby
# Create a new tournament with players and number of rounds
tournament = Swisspairing::Tournament.new(
  players: players,
  total_rounds: 5,
  accelerated: false # Optional: enable acceleration for large tournaments
)
```

### Managing Rounds

```ruby
# Generate pairings for the current round
pairings = tournament.generate_pairings

# Process each pairing
pairings.each do |pairing|
  if pairing.is_bye
    puts "#{pairing.white.name} receives a bye"
    tournament.apply_result(pairing, "1") # Full point for bye
  else
    puts "#{pairing.white.name} (White) vs #{pairing.black.name} (Black)"
    # After the game, apply the result using one of:
    # "1-0"     -> White win
    # "0-1"     -> Black win
    # "1/2-1/2" -> Draw
    # "0-0"     -> Double forfeit
    tournament.apply_result(pairing, "1-0") # Example: white wins
  end
end
```

## Advanced Features

### Tournament Acceleration

For tournaments with many players, acceleration helps strong players meet each other earlier:

```ruby
tournament = Swisspairing::Tournament.new(
  players: players,
  total_rounds: 5,
  accelerated: true # Enable acceleration
)
```

### Color Allocation Rules

The system implements strict FIDE color allocation rules:

- Players should alternate colors when possible
- No player gets the same color three times in a row
- The color difference cannot exceed +2 or -2
- The system considers previous tournament history

### Player Properties

Each player object has the following attributes:

```ruby
player = Swisspairing::Player.new(
  name: "GM Smith",
  rating: 2500,
  title: "GM", # Optional FIDE title
  id: 1       # Optional unique identifier
)

player.score     # Current tournament score
player.opponents # Array of opponent IDs played against
player.colors    # Array of colors played ('W', 'B', or '=' for bye)
```

### Tournament Management

Track tournament progress and history:

```ruby
tournament.current_round # Current round number
tournament.total_rounds  # Total number of rounds
tournament.results      # Array of [pairing, result] for all completed games
```

### Error Handling

The system includes comprehensive error handling:

```ruby
begin
  tournament.generate_pairings
rescue Swisspairing::Error => e
  puts "Tournament error: #{e.message}"
end
```

Common errors handled:
- Invalid result formats
- Tournament already complete
- Invalid player data
- Color allocation conflicts

## FIDE Compliance

This gem strictly follows FIDE Swiss Rules from the FIDE Handbook C.04:

- Initial ranking by rating and title
- Score-based pairing groups
- FIDE color allocation rules
- Acceleration method for large tournaments
- Proper bye handling
- Prevention of repeating pairings

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/LapoElisacci/swisspairing.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
