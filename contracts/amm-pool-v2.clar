;; Stacks AMM DEX v2 - Constant Product Market Maker
;; Simplified version without STX transfers in deploy

;; Constants
(define-constant contract-owner tx-sender)
(define-constant treasury 'SP2PEBKJ2W1ZDDF2QQ6Y4FXKZEDPT9J9R2NKD9WJB)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-insufficient-liquidity (err u102))
(define-constant err-slippage-exceeded (err u103))
(define-constant err-zero-amount (err u104))
(define-constant err-pool-not-found (err u106))

;; Fee: 0.3% (30 basis points)
(define-constant swap-fee u30)
(define-constant fee-denominator u10000)

;; Pool Data
(define-data-var pool-count uint u0)
(define-data-var total-volume uint u0)
(define-data-var total-fees-collected uint u0)

;; Pool storage
(define-map pools uint
  {
    token-x-reserve: uint,
    token-y-reserve: uint,
    lp-token-supply: uint,
    k-last: uint,
    created-block: uint
  }
)

;; LP token balances per pool
(define-map lp-balances { pool-id: uint, owner: principal } uint)

;; User stats
(define-map user-stats principal
  {
    total-swaps: uint,
    total-volume: uint,
    total-liquidity-provided: uint
  }
)

;; Read-only functions
(define-read-only (get-pool (pool-id uint))
  (map-get? pools pool-id)
)

(define-read-only (get-lp-balance (pool-id uint) (owner principal))
  (default-to u0 (map-get? lp-balances { pool-id: pool-id, owner: owner }))
)

(define-read-only (get-pool-count)
  (var-get pool-count)
)

(define-read-only (get-total-volume)
  (var-get total-volume)
)

(define-read-only (get-user-stats (user principal))
  (default-to 
    { total-swaps: u0, total-volume: u0, total-liquidity-provided: u0 }
    (map-get? user-stats user)
  )
)

;; Calculate output amount using constant product formula
(define-read-only (get-amount-out (amount-in uint) (reserve-in uint) (reserve-out uint))
  (let (
    (amount-in-with-fee (/ (* amount-in (- fee-denominator swap-fee)) fee-denominator))
    (numerator (* amount-in-with-fee reserve-out))
    (denominator (+ reserve-in amount-in-with-fee))
  )
    (/ numerator denominator)
  )
)

;; Get price of token X in terms of token Y
(define-read-only (get-price (pool-id uint))
  (match (map-get? pools pool-id)
    pool
    (if (> (get token-x-reserve pool) u0)
      (ok (/ (* (get token-y-reserve pool) u1000000) (get token-x-reserve pool)))
      (err u0)
    )
    (err u0)
  )
)

;; Create a new liquidity pool (simplified - no transfers)
(define-public (create-pool (initial-x uint) (initial-y uint))
  (let (
    (pool-id (var-get pool-count))
    (initial-lp (* initial-x initial-y))
  )
    (asserts! (> initial-x u0) err-zero-amount)
    (asserts! (> initial-y u0) err-zero-amount)
    
    ;; Create pool (accounting only)
    (map-set pools pool-id {
      token-x-reserve: initial-x,
      token-y-reserve: initial-y,
      lp-token-supply: initial-lp,
      k-last: (* initial-x initial-y),
      created-block: stacks-block-height
    })
    
    ;; Mint LP tokens to creator
    (map-set lp-balances { pool-id: pool-id, owner: tx-sender } initial-lp)
    
    ;; Update stats
    (var-set pool-count (+ pool-id u1))
    (map-set user-stats tx-sender 
      (merge (get-user-stats tx-sender)
        { total-liquidity-provided: (+ (get total-liquidity-provided (get-user-stats tx-sender)) initial-x) }
      )
    )
    
    (ok { pool-id: pool-id, lp-tokens: initial-lp })
  )
)

;; Add liquidity to existing pool
(define-public (add-liquidity (pool-id uint) (amount-x uint) (amount-y uint) (min-lp uint))
  (match (map-get? pools pool-id)
    pool
    (let (
      (reserve-x (get token-x-reserve pool))
      (reserve-y (get token-y-reserve pool))
      (lp-supply (get lp-token-supply pool))
      (lp-x (/ (* amount-x lp-supply) reserve-x))
      (lp-y (/ (* amount-y lp-supply) reserve-y))
      (lp-minted (if (< lp-x lp-y) lp-x lp-y))
    )
      (asserts! (>= lp-minted min-lp) err-slippage-exceeded)
      
      ;; Update pool
      (map-set pools pool-id 
        (merge pool {
          token-x-reserve: (+ reserve-x amount-x),
          token-y-reserve: (+ reserve-y amount-y),
          lp-token-supply: (+ lp-supply lp-minted),
          k-last: (* (+ reserve-x amount-x) (+ reserve-y amount-y))
        })
      )
      
      ;; Mint LP tokens
      (map-set lp-balances { pool-id: pool-id, owner: tx-sender }
        (+ (get-lp-balance pool-id tx-sender) lp-minted)
      )
      
      (ok { lp-minted: lp-minted })
    )
    err-pool-not-found
  )
)

;; Remove liquidity from pool
(define-public (remove-liquidity (pool-id uint) (lp-amount uint) (min-x uint) (min-y uint))
  (match (map-get? pools pool-id)
    pool
    (let (
      (user-lp (get-lp-balance pool-id tx-sender))
      (lp-supply (get lp-token-supply pool))
      (reserve-x (get token-x-reserve pool))
      (reserve-y (get token-y-reserve pool))
      (amount-x (/ (* lp-amount reserve-x) lp-supply))
      (amount-y (/ (* lp-amount reserve-y) lp-supply))
    )
      (asserts! (>= user-lp lp-amount) err-insufficient-balance)
      (asserts! (>= amount-x min-x) err-slippage-exceeded)
      (asserts! (>= amount-y min-y) err-slippage-exceeded)
      
      ;; Update pool
      (map-set pools pool-id 
        (merge pool {
          token-x-reserve: (- reserve-x amount-x),
          token-y-reserve: (- reserve-y amount-y),
          lp-token-supply: (- lp-supply lp-amount),
          k-last: (* (- reserve-x amount-x) (- reserve-y amount-y))
        })
      )
      
      ;; Burn LP tokens
      (map-set lp-balances { pool-id: pool-id, owner: tx-sender } (- user-lp lp-amount))
      
      (ok { amount-x: amount-x, amount-y: amount-y })
    )
    err-pool-not-found
  )
)

;; Swap token X for token Y
(define-public (swap-x-for-y (pool-id uint) (amount-in uint) (min-out uint))
  (match (map-get? pools pool-id)
    pool
    (let (
      (reserve-x (get token-x-reserve pool))
      (reserve-y (get token-y-reserve pool))
      (amount-out (get-amount-out amount-in reserve-x reserve-y))
      (fee-amount (/ (* amount-in swap-fee) fee-denominator))
    )
      (asserts! (> amount-in u0) err-zero-amount)
      (asserts! (>= amount-out min-out) err-slippage-exceeded)
      (asserts! (< amount-out reserve-y) err-insufficient-liquidity)
      
      ;; Update pool reserves
      (map-set pools pool-id 
        (merge pool {
          token-x-reserve: (+ reserve-x amount-in),
          token-y-reserve: (- reserve-y amount-out),
          k-last: (* (+ reserve-x amount-in) (- reserve-y amount-out))
        })
      )
      
      ;; Update stats
      (var-set total-volume (+ (var-get total-volume) amount-in))
      (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
      (map-set user-stats tx-sender 
        (merge (get-user-stats tx-sender)
          { 
            total-swaps: (+ (get total-swaps (get-user-stats tx-sender)) u1),
            total-volume: (+ (get total-volume (get-user-stats tx-sender)) amount-in)
          }
        )
      )
      
      (ok { amount-in: amount-in, amount-out: amount-out, fee: fee-amount })
    )
    err-pool-not-found
  )
)

;; Swap token Y for token X
(define-public (swap-y-for-x (pool-id uint) (amount-in uint) (min-out uint))
  (match (map-get? pools pool-id)
    pool
    (let (
      (reserve-x (get token-x-reserve pool))
      (reserve-y (get token-y-reserve pool))
      (amount-out (get-amount-out amount-in reserve-y reserve-x))
      (fee-amount (/ (* amount-in swap-fee) fee-denominator))
    )
      (asserts! (> amount-in u0) err-zero-amount)
      (asserts! (>= amount-out min-out) err-slippage-exceeded)
      (asserts! (< amount-out reserve-x) err-insufficient-liquidity)
      
      ;; Update pool reserves
      (map-set pools pool-id 
        (merge pool {
          token-x-reserve: (- reserve-x amount-out),
          token-y-reserve: (+ reserve-y amount-in),
          k-last: (* (- reserve-x amount-out) (+ reserve-y amount-in))
        })
      )
      
      ;; Update stats
      (var-set total-volume (+ (var-get total-volume) amount-in))
      (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
      
      (ok { amount-in: amount-in, amount-out: amount-out, fee: fee-amount })
    )
    err-pool-not-found
  )
)


