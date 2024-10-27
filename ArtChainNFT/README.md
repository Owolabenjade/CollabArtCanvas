# Art Canvas Smart Contract

A decentralized collaborative art platform built on Stacks blockchain that allows users to contribute to a shared canvas, mint NFTs of snapshots, and participate in revenue sharing. The contract manages user contributions, canvas evolution, and fair distribution of funds among contributors.

## Features
- **Canvas Contributions**: Users can add visual elements to the canvas with customizable properties
- **Evolution Tracking**: Each contribution is captured as a snapshot in the canvas history
- **NFT Minting**: Contributors can mint NFTs of canvas snapshots
- **Revenue Sharing**: Built-in treasury and fair distribution system for contributors
- **Contribution Limits**: Maximum of 100 contributors to ensure platform stability

## Contract Structure

### Data Storage

#### Maps
1. `contributors`: Stores contributor details
   ```clarity
   { contributor: principal } -> {
       color: (optional (buff 32)),
       size: (optional uint),
       pattern: (optional (buff 32))
   }
   ```

2. `canvas-snapshots`: Tracks canvas evolution
   ```clarity
   { snapshot-id: uint } -> {
       contributor: principal,
       color: (optional (buff 32)),
       size: (optional uint),
       pattern: (optional (buff 32))
   }
   ```

3. `revenue-share`: Records distributed funds
   ```clarity
   { contributor: principal } -> { amount: uint }
   ```

#### Variables
- `total-snapshots`: Total number of minted NFTs
- `total-contributions`: Total number of contributions
- `treasury`: Current treasury balance
- `last-distributed-index`: Tracks fund distribution progress
- `contributors-list`: List of all contributors (max 100)

### Error Codes
- `ERR_NOT_AUTHORIZED (u100)`: Unauthorized access attempt
- `ERR_ALREADY_CONTRIBUTED (u101)`: Duplicate contribution attempt
- `ERR_NO_BALANCE (u102)`: Insufficient treasury balance
- `ERR_INVALID_AMOUNT (u103)`: Invalid fund amount
- `ERR_INVALID_COLOR_SIZE (u104)`: Invalid color buffer size
- `ERR_INVALID_PATTERN_SIZE (u105)`: Invalid pattern buffer size
- `ERR_INVALID_SIZE_VALUE (u106)`: Invalid size value

## Public Functions

### contribute
```clarity
(define-public (contribute (color (optional (buff 32))) 
                         (size (optional uint)) 
                         (pattern (optional (buff 32))))
```
Add a new contribution to the canvas with validation checks.

**Parameters:**
- `color`: Optional 32-byte buffer for color data
- `size`: Optional uint for element size (1-100)
- `pattern`: Optional 32-byte buffer for pattern data

**Returns:**
- Success: `(ok principal)` - Contributor's principal
- Error: Various error codes based on validation

### mint-snapshot
```clarity
(define-public (mint-snapshot))
```
Creates an NFT of the current canvas state.

**Returns:**
- Success: `(ok { snapshot-id: uint, contributor: principal })`
- Error: `ERR_NOT_AUTHORIZED` if not a contributor

### contribute-funds
```clarity
(define-public (contribute-funds (amount uint)))
```
Add funds to the treasury.

**Parameters:**
- `amount`: Amount to contribute (must be > 0)

**Returns:**
- Success: `(ok uint)` - New treasury balance
- Error: `ERR_INVALID_AMOUNT` if amount ≤ 0

### distribute-funds-step
```clarity
(define-public (distribute-funds-step))
```
Distributes funds to contributors one at a time.

**Returns:**
- Success: Status object with distribution details
- Error: Various error codes based on validation

## Read-Only Functions

### get-current-snapshot
```clarity
(define-read-only (get-current-snapshot))
```
Returns the latest canvas snapshot.

### get-canvas-evolution
```clarity
(define-read-only (get-canvas-evolution))
```
Returns the history of canvas changes (last 5 snapshots).

### get-revenue-share
```clarity
(define-read-only (get-revenue-share (contributor principal)))
```
Returns the revenue share for a specific contributor.

### get-all-contributions
```clarity
(define-read-only (get-all-contributions))
```
Returns the total number of contributions.

## Usage Examples

### Making a Contribution
```clarity
;; Contribute with color and size
(contract-call? .art-canvas contribute 
    (some 0x000000) ;; black color
    (some u50)      ;; medium size
    none)           ;; no pattern
```

### Contributing Funds
```clarity
;; Add 1000 microSTX to treasury
(contract-call? .art-canvas contribute-funds u1000)
```

### Minting a Snapshot
```clarity
;; Mint current canvas state as NFT
(contract-call? .art-canvas mint-snapshot)
```

## Security Features
1. Input validation for all user-provided data
2. Buffer size checks for color and pattern data
3. Size value constraints (1-100)
4. Contribution uniqueness checks
5. Authorization checks for privileged operations
6. Safe list management with explicit length checks
7. Protected treasury operations

## Limitations
1. Maximum 100 contributors
2. Fixed canvas element size range (1-100)
3. Only last 5 snapshots in evolution history
4. One contribution per address
5. Sequential fund distribution

## Best Practices
1. Always check function return values
2. Verify transaction success before proceeding
3. Keep color and pattern data within size limits
4. Monitor treasury balance before distribution
5. Handle optional values appropriately

## Development and Testing
Recommended testing scenarios:
1. Valid and invalid contributions
2. Treasury operations
3. NFT minting
4. Fund distribution
5. Canvas evolution tracking