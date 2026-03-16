# ⬡ Pyth Defender — Hero of the Crypto Realm

> A browser-based space shooter powered by live **Pyth Price Feeds** and **Pyth Entropy**. No install. No wallet required to play. Opens in any browser.

![License](https://img.shields.io/badge/license-Apache%202.0-purple)
![Pyth](https://img.shields.io/badge/powered%20by-Pyth%20Network-blueviolet)
![Hackathon](https://img.shields.io/badge/Pyth%20Playground-2026-orange)

---

## 🎮 Play Now

👉 **[Launch Game](https://YOUR_USERNAME.github.io/pyth-defender/game.html)**

---

## What It Does

Pyth Defender is a full arcade space shooter. You pilot a PYTH ship defending the last oracle node from the **FUD Syndicate**  waves of drones, bots, REKT Missiles, and a 3-phase boss called the **Crypto Kraken**.

- **6 waves** of escalating difficulty with a wave timer
- **6 weapon tiers** unlocking as you advance (Diamond Shot → Void Cannon)
- **3-life system** with shield bubble airdrops
- **60-second cinematic story intro** with the Pyth logo throughout
- **Global leaderboard** via Supabase — real scores from all players
- **Beat notification** — tells you in real time when you pass someone on the board

---

## ⬡ Pyth Integration

### Price Feeds — Pyth Hermes REST API
Calls `https://hermes.pyth.network/api/latest_price_feeds` every 4 seconds.

| Asset | Feed ID |
|-------|---------|
| BTC/USD | `e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43` |
| ETH/USD | `ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace` |
| SOL/USD | `ef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d` |
| BNB/USD | `2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f` |

- Prices appear live on the HUD with ▲/▼ change indicators
- When an enemy is destroyed, the live price of their asset floats up from the explosion
- Price parsing uses `parseInt()` (not `parseFloat`) to avoid precision loss on large integers

### Entropy — Commit-Reveal Protocol
Implements the Pyth Entropy commit-reveal scheme in the browser:

```
Provider seed  = Pyth price confidence interval (live oracle data)
User seed      = crypto.getRandomValues()  (CSPRNG commit phase)
Reveal         = FNV-1a hash(userSeed XOR providerSeed XOR nonce)
```

- Output value gates airdrop spawning (threshold: entropy < 0.06)
- Rarity tiers: **shield bubble** (2.5%) · **score bonus** (2%) · **extra life** (1.5%)
- Pyth Entropy bar is always visible in the leaderboard panel
- During Kraken boss fights: 2 guaranteed shield drops are forced so players can survive

### On-Chain Entropy — PythDefenderScores.sol
`PythDefenderScores.sol` deploys on **Optimism Sepolia** and calls `entropy.requestV2()` on the real Pyth Entropy contract. Pyth Fortuna's callback assigns a verifiable random bonus multiplier:

| Tier | Multiplier | Probability |
|------|-----------|-------------|
| Base | 1.0× | 50% |
| Uncommon | 1.25× | 25% |
| Rare | 1.5× | 15% |
| Epic | 2.0× | 8% |
| Legendary | 2.5× | 2% |

---

## 📁 File Structure

```
pyth-defender/
├── game.html                  ← Full playable game (open in any browser)
├── game-submit.html           ← MetaMask UI for on-chain score submission
├── index.html                 ← Redirects to game (GitHub Pages entry point)
├── PythDefenderScores.sol     ← Pyth Entropy V2 smart contract
├── deploy.sh                  ← Deploy contract to Optimism Sepolia
├── LICENSE                    ← Apache 2.0
└── README.md                  ← This file
```

---

## 🚀 Run Locally

Just open `game.html` in any modern browser. No server, no dependencies, no npm install.

```bash
# That's it — open in Chrome/Firefox/Safari/Edge
open game.html
```

---

## ⛓️ Deploy the Contract (Optional)

Requires [Foundry](https://book.getfoundry.sh/) and testnet ETH from [console.optimism.io/faucet](https://console.optimism.io/faucet).

```bash
npm install @pythnetwork/entropy-sdk-solidity
export PRIVATE_KEY=0x<your_key>
./deploy.sh
```

Then paste the deployed address into `game-submit.html` at `CONTRACT_ADDRESS = '...'`.

---

## 🛠️ Tech Stack

- **Game:** Vanilla HTML5 Canvas + JavaScript (zero dependencies, single file)
- **Price Feeds:** Pyth Hermes REST API
- **Entropy:** Pyth Entropy V2 on Optimism Sepolia (`PythDefenderScores.sol`)
- **Leaderboard:** Supabase (free tier, global cross-device scores)
- **Deployment:** GitHub Pages

---

## 📝 Pyth Playground Hackathon 2026

Submitted to the [Pyth Playground Community Hackathon](https://dev-forum.pyth.network/c/pyth-hackathon/14).

- **Pyth Features Used:** Price Feeds + Entropy (both)
- **Deadline:** April 1, 2026

---

## License

Apache 2.0 — see [LICENSE](LICENSE)
