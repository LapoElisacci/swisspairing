# frozen_string_literal: true

RSpec.describe Swisspairing do
  it "has a version number" do
    expect(Swisspairing::VERSION).not_to be nil
  end

  let(:players) do
    [
      Swisspairing::Player.new(name: "GM Player", rating: 2500, title: "GM", id: 1),
      Swisspairing::Player.new(name: "IM Player", rating: 2400, title: "IM", id: 2),
      Swisspairing::Player.new(name: "FM Player", rating: 2300, title: "FM", id: 3),
      Swisspairing::Player.new(name: "Player A", rating: 2200, id: 4),
      Swisspairing::Player.new(name: "Player B", rating: 2100, id: 5)
    ]
  end

  describe "Tournament" do
    let(:tournament) { Swisspairing::Tournament.new(players: players, total_rounds: 3) }

    it "sorts players correctly by rating and title" do
      expect(tournament.players.map(&:name)).to eq([
        "GM Player", "IM Player", "FM Player", "Player A", "Player B"
      ])
    end

    it "generates valid first round pairings" do
      pairings = tournament.generate_pairings
      expect(pairings.length).to be((players.length / 2.0).ceil)
      expect(pairings.any?(&:is_bye)).to be(players.length.odd?)
    end

    it "applies results correctly" do
      pairings = tournament.generate_pairings
      first_pairing = pairings.first
      tournament.apply_result(first_pairing, "1-0")

      expect(first_pairing.white.score).to eq(1)
      expect(first_pairing.black.score).to eq(0)
    end

    it "handles color balance" do
      first_round = tournament.generate_pairings
      # Give white win in first pairing
      tournament.apply_result(first_round.first, "1-0")
      # Give black win in second pairing
      tournament.apply_result(first_round[1], "0-1")

      second_round = tournament.generate_pairings
      # Players who had white should tend to get black and vice versa
      expect(second_round.first.white.colors.last).not_to eq("W")
    end

    it "prevents players from playing each other twice" do
      first_round = tournament.generate_pairings
      first_round.each { |p| tournament.apply_result(p, "1-0") unless p.is_bye }

      second_round = tournament.generate_pairings
      all_pairings = first_round + second_round

      # Check that no two players played against each other twice
      player_pairs = all_pairings.reject(&:is_bye).map { |p| [p.white.id, p.black.id].sort }
      expect(player_pairs.uniq.length).to eq(player_pairs.length)
    end

    it "handles byes fairly" do
      return unless players.length.odd?

      all_pairings = []
      3.times do
        round_pairings = tournament.generate_pairings
        round_pairings.each { |p| tournament.apply_result(p, p.is_bye ? "1" : "1-0") }
        all_pairings += round_pairings
      end

      bye_recipients = all_pairings.select(&:is_bye).map { |p| p.white.id }
      expect(bye_recipients.uniq.length).to eq(bye_recipients.length)
    end
  end

  describe "Tournament with acceleration" do
    let(:tournament) { Swisspairing::Tournament.new(players: players, total_rounds: 3, accelerated: true) }

    it "accelerates top half players in first two rounds" do
      first_round = tournament.generate_pairings
      first_pairing = first_round.first

      # Check that acceleration affected the pairings
      expect(first_pairing.white.rating).to be > first_pairing.black.rating

      # Apply results and check second round
      first_round.each { |p| tournament.apply_result(p, p.is_bye ? "1" : "1-0") }

      second_round = tournament.generate_pairings
      # Verify acceleration is still active in round 2
      expect(second_round.first.white.rating).to be > second_round.first.black.rating
    end
  end

  describe "Tournament standings and tie-breaks" do
    let(:tournament) { Swisspairing::Tournament.new(players: players, total_rounds: 3) }

    it "calculates standings with tie-breaks" do
      # Play two rounds
      2.times do
        pairings = tournament.generate_pairings
        pairings.each { |p| tournament.apply_result(p, p.is_bye ? "1" : "1-0") }
      end

      standings = tournament.standings
      first_place = standings.first
      second_place = standings[1]

      # If players have same score, tie-breaks should determine order
      if first_place.score == second_place.score
        expect(first_place.buchholz_score(players)).to be >= second_place.buchholz_score(players)
      else
        expect(first_place.score).to be > second_place.score
      end
    end

    it "calculates Sonneborn-Berger scores correctly" do
      # Play one round with a draw
      pairings = tournament.generate_pairings
      tournament.apply_result(pairings.first, "½-½")

      white_player = pairings.first.white
      black_player = pairings.first.black

      # Both players should have Sonneborn-Berger scores of their opponent's score / 2
      expect(white_player.sonneborn_berger_score(players, tournament.results))
        .to eq(black_player.score / 2.0)
    end
  end

  describe "Enhanced color allocation" do
    let(:tournament) { Swisspairing::Tournament.new(players: players, total_rounds: 5) }

    it "maintains color balance within acceptable limits" do
      4.times do
        pairings = tournament.generate_pairings
        pairings.each { |p| tournament.apply_result(p, p.is_bye ? "1" : "1-0") }
      end

      players.each do |player|
        # No player should have more than 2 more whites than blacks or vice versa
        expect(player.color_balance.abs).to be <= 2
      end
    end

    it "avoids three consecutive same colors" do
      3.times do
        pairings = tournament.generate_pairings
        pairings.each { |p| tournament.apply_result(p, p.is_bye ? "1" : "1-0") }
      end

      players.each do |player|
        # Check no three consecutive same colors
        player.colors.each_cons(3) do |three_colors|
          expect(three_colors.uniq.length).to be > 1
        end
      end
    end
  end
end
