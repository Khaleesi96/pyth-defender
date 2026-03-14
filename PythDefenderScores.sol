// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

/**
 * @title PythDefenderScores
 * @notice On-chain score submission for Pyth Defender game.
 *         Uses Pyth Entropy V2 to generate a verifiable random bonus
 *         multiplier when a player submits their score.
 *
 * Deploy on Optimism Sepolia (testnet):
 *   ENTROPY_ADDRESS = 0x4821932D0CDd71225A6d914706A621e0389D7061
 *   PROVIDER        = 0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344
 *
 * Deploy on Optimism Mainnet:
 *   ENTROPY_ADDRESS = 0xdF21D137Aadc95588205586636710ca2890538d5
 *   PROVIDER        = 0x52DeaA1c84233F7bb8C8A45baeDE41091c616506
 */
contract PythDefenderScores is IEntropyConsumer {

    // ── Events ──────────────────────────────────────────────────────────
    event ScoreSubmitted(
        uint64 indexed sequenceNumber,
        address indexed player,
        string  playerName,
        uint256 rawScore,
        uint256 wave
    );
    event ScoreFinalized(
        uint64  indexed sequenceNumber,
        address indexed player,
        string  playerName,
        uint256 rawScore,
        uint256 bonusMultiplierBps,   // basis points: 10000 = 1.0x, 15000 = 1.5x
        uint256 finalScore,
        bytes32 entropyRandomNumber   // verifiable on-chain random from Pyth
    );

    // ── Structs ──────────────────────────────────────────────────────────
    struct PendingScore {
        address player;
        string  playerName;
        uint256 rawScore;
        uint256 wave;
        bool    exists;
    }

    struct LeaderboardEntry {
        address player;
        string  playerName;
        uint256 finalScore;
        uint256 wave;
        uint256 bonusMultiplierBps;
        uint64  timestamp;
    }

    // ── State ─────────────────────────────────────────────────────────────
    IEntropyV2 private immutable entropy;
    address    private immutable provider;

    // sequenceNumber => pending score awaiting Pyth callback
    mapping(uint64 => PendingScore) public pendingScores;

    // player address => their best finalized entry
    mapping(address => LeaderboardEntry) public bestScores;

    // top 20 leaderboard (ordered externally by reading allEntries)
    address[] public rankedPlayers;
    uint256   public constant MAX_LEADERBOARD = 20;

    // ── Constructor ───────────────────────────────────────────────────────
    constructor(address _entropy, address _provider) {
        entropy  = IEntropyV2(_entropy);
        provider = _provider;
    }

    // Required by IEntropyConsumer
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    // ── Submit score ──────────────────────────────────────────────────────
    /**
     * @notice Submit a game score. Pays Pyth Entropy fee.
     *         Pyth will call back `entropyCallback` with a random number
     *         that determines the bonus multiplier (1.0x – 2.5x).
     * @param playerName  Display name (max 12 chars)
     * @param rawScore    Score achieved in the game
     * @param wave        Wave reached
     */
    function submitScore(
        string calldata playerName,
        uint256 rawScore,
        uint256 wave
    ) external payable {
        require(bytes(playerName).length > 0 && bytes(playerName).length <= 12,
            "Name must be 1-12 chars");
        require(rawScore > 0, "Score must be > 0");
        require(wave > 0 && wave <= 20, "Wave out of range");

        // Get required fee from Pyth Entropy
        uint128 fee = entropy.getFeeV2();
        require(msg.value >= fee, "Insufficient fee for Pyth Entropy");

        // Request verifiable random number from Pyth Entropy V2
        uint64 sequenceNumber = entropy.requestV2{value: fee}();

        // Store pending score, will be finalized in callback
        pendingScores[sequenceNumber] = PendingScore({
            player:     msg.sender,
            playerName: playerName,
            rawScore:   rawScore,
            wave:       wave,
            exists:     true
        });

        emit ScoreSubmitted(sequenceNumber, msg.sender, playerName, rawScore, wave);

        // Refund excess ETH
        uint256 excess = msg.value - fee;
        if (excess > 0) {
            (bool ok,) = payable(msg.sender).call{value: excess}("");
            require(ok, "Refund failed");
        }
    }

    // ── Pyth Entropy Callback ─────────────────────────────────────────────
    /**
     * @notice Called by Pyth Entropy with the verifiable random number.
     *         Computes bonus multiplier and finalizes score on leaderboard.
     */
    function entropyCallback(
        uint64  sequenceNumber,
        address /* _provider */,
        bytes32 randomNumber
    ) internal override {
        PendingScore storage p = pendingScores[sequenceNumber];
        require(p.exists, "Unknown sequence");

        // ── Derive bonus multiplier from Pyth random number ──────────────
        // Map random bytes to a multiplier in basis points:
        //   Tiers:     1.0x (10000 bps) — 50% chance  (score ≥ 0)
        //              1.25x (12500 bps) — 25% chance
        //              1.5x  (15000 bps) — 15% chance
        //              2.0x  (20000 bps) — 8%  chance
        //              2.5x  (25000 bps) — 2%  chance  (jackpot!)
        uint256 roll = uint256(randomNumber) % 100;
        uint256 multiplierBps;
        if      (roll < 50) multiplierBps = 10000;   // 1.00x — base
        else if (roll < 75) multiplierBps = 12500;   // 1.25x — uncommon
        else if (roll < 90) multiplierBps = 15000;   // 1.50x — rare
        else if (roll < 98) multiplierBps = 20000;   // 2.00x — epic
        else                multiplierBps = 25000;   // 2.50x — legendary

        uint256 finalScore = (p.rawScore * multiplierBps) / 10000;

        // ── Update leaderboard ──────────────────────────────────────────
        LeaderboardEntry storage current = bestScores[p.player];
        if (finalScore > current.finalScore) {
            bool isNewPlayer = current.finalScore == 0;
            current.player            = p.player;
            current.playerName        = p.playerName;
            current.finalScore        = finalScore;
            current.wave              = p.wave;
            current.bonusMultiplierBps = multiplierBps;
            current.timestamp         = uint64(block.timestamp);

            if (isNewPlayer) {
                rankedPlayers.push(p.player);
            }
        }

        emit ScoreFinalized(
            sequenceNumber,
            p.player,
            p.playerName,
            p.rawScore,
            multiplierBps,
            finalScore,
            randomNumber
        );

        delete pendingScores[sequenceNumber];
    }

    // ── Read functions ────────────────────────────────────────────────────

    /// @notice Get the current Pyth Entropy fee (pass this as msg.value to submitScore)
    function getEntropyFee() external view returns (uint128) {
        return entropy.getFeeV2();
    }

    /// @notice Get top N players sorted by finalScore descending
    function getLeaderboard(uint256 n)
        external view
        returns (LeaderboardEntry[] memory)
    {
        uint256 count = rankedPlayers.length < n ? rankedPlayers.length : n;
        LeaderboardEntry[] memory entries = new LeaderboardEntry[](count);
        for (uint256 i = 0; i < count; i++) {
            entries[i] = bestScores[rankedPlayers[i]];
        }
        // Simple bubble sort (gas-acceptable for small leaderboard reads)
        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = i+1; j < count; j++) {
                if (entries[j].finalScore > entries[i].finalScore) {
                    LeaderboardEntry memory tmp = entries[i];
                    entries[i] = entries[j];
                    entries[j] = tmp;
                }
            }
        }
        return entries;
    }

    /// @notice Total number of unique players on leaderboard
    function playerCount() external view returns (uint256) {
        return rankedPlayers.length;
    }
}
