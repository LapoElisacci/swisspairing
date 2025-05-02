# SwissPairing

A Ruby gem that implements FIDE-compliant Swiss pairing system for chess tournaments. This gem follows the official FIDE Swiss Rules effective from July 1, 2025.

## Features

- FIDE-compliant Swiss pairing system
- Handles player ratings and FIDE titles
- Supports tournament scoring and results
- Manages color allocation according to FIDE rules
- Handles byes for odd numbers of players
- Prevents rematches between players

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

## Usage

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
tournament = Swisspairing::Tournament.new(players: players, total_rounds: 5)
```

### Generating Pairings

```ruby
# Generate pairings for the current round
pairings = tournament.generate_pairings

# Process each pairing
pairings.each do |pairing|
  if pairing.is_bye
    puts "#{pairing.white.name} receives a bye"
    tournament.apply_result(pairing, "1")
  else
    puts "#{pairing.white.name} (White) vs #{pairing.black.name} (Black)"
    # After the game, apply the result:
    # "1-0" for white win
    # "0-1" for black win
    # "½-½" for draw
    tournament.apply_result(pairing, "1-0") # example: white wins
  end
end
```

## Advanced Features

### Acceleration

For tournaments with many players, you can enable acceleration to help stronger players meet each other earlier:

```ruby
tournament = Swisspairing::Tournament.new(
  players: players,
  total_rounds: 5,
  accelerated: true # Enable acceleration
)
```

### Tie-Breaks

The system implements official FIDE tie-break systems:

1. Direct score
2. Buchholz score (sum of opponents' scores)
3. Sonneborn-Berger score
4. Rating

Get tournament standings with tie-breaks:

```ruby
standings = tournament.standings
standings.each_with_index do |player, index|
  puts "#{index + 1}. #{player.name} (#{player.score} pts)"
end
```

### Color Allocation

The system follows strict FIDE color allocation rules:

- No player gets the same color three times in a row
- Color difference cannot exceed +2 or -2
- Players alternate colors when possible
- Color allocation considers previous tournament history

## FIDE Compliance

This gem strictly follows FIDE Swiss Rules from the FIDE Handbook C.04:

- C.04.1: Basic Rules for Swiss Systems
- C.04.2: General Handling Rules
- C.04.3: FIDE (Dutch) System

Features include:
- Proper initial ranking by rating and title
- Score-based pairing groups
- Correct color allocation rules
- Acceleration method for large tournaments
- Official tie-break systems
- Proper handling of byes and odd numbers of players

## Error Handling

The system includes various safeguards:

```ruby
begin
  tournament.generate_pairings
rescue Swisspairing::Error => e
  puts "Tournament error: #{e.message}"
end
```

Common errors:
- Tournament already complete
- Invalid result format
- Invalid player data

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
