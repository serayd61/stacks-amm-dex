# Stacks AMM DEX

A minimal, production-ready decentralized exchange (DEX) on Stacks (Bitcoin L2) implementing a constant-product AMM (x · y = k).

## Features

- **Constant Product AMM**: Automated market making using the x * y = k formula
- **Liquidity Pools**: Create and manage liquidity pools for any token pair
- **LP Tokens**: Receive LP tokens representing your share of the pool
- **Swap Fees**: 0.3% swap fee distributed to liquidity providers
- **Slippage Protection**: Built-in slippage checks for all operations

## Smart Contract Functions

### Pool Management
- `create-pool`: Create a new liquidity pool with initial reserves
- `add-liquidity`: Add liquidity to an existing pool
- `remove-liquidity`: Remove liquidity and receive underlying tokens

### Trading
- `swap-x-for-y`: Swap token X for token Y
- `swap-y-for-x`: Swap token Y for token X
- `get-amount-out`: Calculate output amount for a given input
- `get-amount-in`: Calculate required input for desired output

### Read-Only
- `get-pool`: Get pool information
- `get-lp-balance`: Get user's LP token balance
- `get-price`: Get current price in the pool
- `get-user-stats`: Get user trading statistics

## Technical Details

### Constant Product Formula
```
x * y = k
```
Where:
- `x` = Reserve of token X
- `y` = Reserve of token Y
- `k` = Constant product (invariant)

### Fee Structure
- Swap fee: 0.3% (30 basis points)
- Fees are retained in the pool, benefiting LP holders

### Price Impact
Price impact increases with trade size relative to pool liquidity:
```
price_impact = amount_in / (reserve_in + amount_in)
```

## Installation

```bash
# Clone the repository
git clone https://github.com/serayd61/stacks-amm-dex.git

# Install Clarinet
curl -L https://github.com/hirosystems/clarinet/releases/download/v2.0.0/clarinet-linux-x64.tar.gz | tar xz

# Run tests
clarinet test
```

## Contract Deployment

```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet
stx deploy_contract ./contracts/amm-pool.clar amm-pool <fee> <nonce> <private_key>
```

## Usage Example

```clarity
;; Create a pool with 1000 STX and 10000 tokens
(contract-call? .amm-pool create-pool u1000000000 u10000000000)

;; Swap 10 STX for tokens (minimum 90 tokens expected)
(contract-call? .amm-pool swap-x-for-y u0 u10000000 u90000000)

;; Add liquidity
(contract-call? .amm-pool add-liquidity u0 u100000000 u1000000000 u0)

;; Remove liquidity
(contract-call? .amm-pool remove-liquidity u0 u1000 u0 u0)
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AMM Pool Contract                     │
├─────────────────────────────────────────────────────────┤
│  Pool Storage                                            │
│  ├── token-x-reserve                                     │
│  ├── token-y-reserve                                     │
│  ├── lp-token-supply                                     │
│  └── k-last (invariant)                                  │
├─────────────────────────────────────────────────────────┤
│  LP Token Balances                                       │
│  └── (pool-id, owner) -> balance                         │
├─────────────────────────────────────────────────────────┤
│  Core Functions                                          │
│  ├── create-pool                                         │
│  ├── add-liquidity                                       │
│  ├── remove-liquidity                                    │
│  ├── swap-x-for-y                                        │
│  └── swap-y-for-x                                        │
└─────────────────────────────────────────────────────────┘
```

## Security Considerations

- All arithmetic operations use unsigned integers to prevent overflow
- Slippage protection on all swap and liquidity operations
- K-invariant validation ensures pool integrity
- No external calls that could cause reentrancy

## License

MIT License

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity)
- [Hiro Platform](https://platform.hiro.so/)

