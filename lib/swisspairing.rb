# frozen_string_literal: true

require_relative "swisspairing/version"

module Swisspairing
  class Error < StandardError; end

  FIDE_TITLES = %w[GM IM WGM FM WIM CM WFM WCM].freeze

  class Player
    attr_reader :name, :rating, :title, :id
    attr_accessor :score, :opponents, :colors

    def initialize(name:, rating:, title: nil, id: nil)
      @name = name
      @rating = rating.to_i
      @title = title if FIDE_TITLES.include?(title)
      @id = id
      @score = 0
      @opponents = []
      @colors = [] # 'W' for white, 'B' for black, '=' for bye
    end

    def color_balance
      colors.count('W') - colors.count('B')
    end

    def can_receive_bye?
      !colors.include?('=')
    end

    def played_against?(player)
      opponents.include?(player.id)
    end

    # Buchholz score (sum of opponents' scores)
    def buchholz_score(all_players)
      opponents.sum { |opp_id| all_players.find { |p| p.id == opp_id }&.score || 0 }
    end

    # Sonneborn-Berger score
    def sonneborn_berger_score(all_players, results)
      results.sum do |pairing, result|
        next 0 unless [pairing.white.id, pairing.black.id].include?(id)
        opponent = pairing.white.id == id ? pairing.black : pairing.white
        opponent_score = opponent.score
        if pairing.white.id == id
          result == "1-0" ? opponent_score : (result == "½-½" ? opponent_score / 2.0 : 0)
        else
          result == "0-1" ? opponent_score : (result == "½-½" ? opponent_score / 2.0 : 0)
        end
      end
    end
  end

  class Tournament
    attr_reader :players, :current_round, :total_rounds, :results

    def initialize(players:, total_rounds:, accelerated: false)
      @players = players
      @total_rounds = total_rounds
      @current_round = 0
      @results = []
      @accelerated = accelerated
      validate_and_sort_players
    end

    def standings
      players.sort_by do |player|
        [
          -player.score,
          -player.buchholz_score(players),
          -player.sonneborn_berger_score(players, @results),
          -player.rating
        ]
      end
    end

    def generate_pairings
      raise Error, "Tournament is complete" if @current_round >= @total_rounds

      @current_round += 1
      score_groups = players.group_by(&:score).sort_by { |score, _| -score }.to_h
      pairings = []
      unpaired_players = []

      score_groups.each do |score, players_in_group|
        # Add any unpaired players from higher score groups
        group_players = unpaired_players + players_in_group
        unpaired_players = []

        while group_players.size >= 2
          white_candidate = group_players.first
          possible_opponents = group_players[1..]
                               .reject { |p| white_candidate.played_against?(p) }
                               .select { |p| valid_colors?(white_candidate, p) }

          if possible_opponents.empty?
            unpaired_players << group_players.shift
            next
          end

          black_candidate = select_best_opponent(white_candidate, possible_opponents)
          group_players.delete(black_candidate)
          group_players.shift # remove white_candidate

          # Determine colors based on previous allocations
          if should_swap_colors?(white_candidate, black_candidate)
            pairings << Pairing.new(white: black_candidate, black: white_candidate)
          else
            pairings << Pairing.new(white: white_candidate, black: black_candidate)
          end
        end

        # Add remaining player to unpaired list for next score group
        unpaired_players.concat(group_players) if group_players.any?
      end

      # Handle remaining unpaired player with a bye if necessary
      if unpaired_players.any?
        bye_player = select_bye_player(unpaired_players)
        pairings << Pairing.new(white: bye_player)
      end

      if @accelerated && @current_round <= 2
        accelerate_pairings(score_groups)
      end

      pairings
    end

    def apply_result(pairing, result)
      case result
      when "1-0"
        pairing.white.score += 1
      when "0-1"
        pairing.black.score += 1
      when "½-½"
        pairing.white.score += 0.5
        pairing.black.score += 0.5
      when "1"  # bye
        pairing.white.score += 1 if pairing.is_bye
      else
        raise Error, "Invalid result: #{result}"
      end

      unless pairing.is_bye
        pairing.white.opponents << pairing.black.id
        pairing.black.opponents << pairing.white.id
        pairing.white.colors << "W"
        pairing.black.colors << "B"
      else
        pairing.white.colors << "="
      end

      @results << [pairing, result]
    end

    private

    def validate_and_sort_players
      # Sort by rating, title, and name as per FIDE rules 2.2
      @players.sort_by! do |player|
        [
          -player.rating,
          -(FIDE_TITLES.index(player.title) || FIDE_TITLES.length),
          player.name
        ]
      end
    end

    def accelerate_pairings(score_groups)
      return unless @accelerated && @current_round <= 2

      # Split players into top and bottom half for acceleration
      mid_point = (@players.length / 2.0).ceil
      top_half = @players[0...mid_point]
      bottom_half = @players[mid_point..]

      # Add virtual point to top half players in first two rounds
      top_half.each { |p| p.score += 1 } if @current_round <= 2
    end

    def valid_colors?(player1, player2)
      return true if player1.colors.empty? || player2.colors.empty?

      # Enhanced color allocation rules
      [player1, player2].none? do |p|
        # No more than two same colors in a row
        p.colors.last(2) == ["W", "W"] || p.colors.last(2) == ["B", "B"] ||
        # No color difference > 2
        p.color_balance.abs > 2 ||
        # No same color three times more than the other
        p.colors.count("W") > (p.colors.count("B") + 2) ||
        p.colors.count("B") > (p.colors.count("W") + 2)
      end
    end

    def should_swap_colors?(white, black)
      return true if white.color_balance > black.color_balance + 1
      return true if white.colors.last == "W" && black.colors.last == "B"
      false
    end

    def select_best_opponent(player, candidates)
      # Select opponent with closest score and rating
      candidates.min_by do |candidate|
        [
          (candidate.score - player.score).abs,
          (candidate.rating - player.rating).abs
        ]
      end
    end

    def select_bye_player(candidates)
      # Select player with lowest score who hasn't had a bye
      candidates.select(&:can_receive_bye?)
                .min_by { |p| [p.score, p.rating] } || candidates.first
    end
  end

  class Pairing
    attr_reader :white, :black, :is_bye

    def initialize(white:, black: nil)
      @white = white
      @black = black
      @is_bye = black.nil?
    end
  end
end
