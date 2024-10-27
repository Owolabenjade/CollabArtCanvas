(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_ALREADY_CONTRIBUTED u101)
(define-constant ERR_NO_BALANCE u102)
(define-constant ERR_INVALID_AMOUNT u103)

;; Map of contributors and their parameters
(define-map contributors
    { contributor: principal }
    {
        color: (optional (buff 32)),
        size: (optional uint),
        pattern: (optional (buff 32))
    })

;; Map of NFT snapshots of canvas at different contribution stages
(define-map canvas-snapshots
    { snapshot-id: uint }
    {
        contributor: principal,
        color: (optional (buff 32)),
        size: (optional uint),
        pattern: (optional (buff 32))
    })

(define-data-var total-snapshots uint u0)
(define-data-var total-contributions uint u0)
(define-data-var treasury uint u0)

;; Record of revenue share for each contributor
(define-map revenue-share
    { contributor: principal }
    { amount: uint })

;; Event logs
(define-event contribution-logged (contributor principal color (optional (buff 32)) size (optional uint) pattern (optional (buff 32))))
(define-event snapshot-minted (snapshot-id uint contributor principal))
(define-event funds-distributed (contributor principal amount uint))

;; Function: Contribute to the canvas
(define-public (contribute (color (optional (buff 32))) (size (optional uint)) (pattern (optional (buff 32))))
    (let ((contributor tx-sender))
        ;; Check if contributor already contributed
        (if (is-none (map-get? contributors { contributor: contributor }))
            (begin
                ;; Log contribution in contributors map
                (map-set contributors
                    { contributor: contributor }
                    { color: color, size: size, pattern: pattern })
                
                ;; Log the contribution as an event
                (emit-event (contribution-logged contributor color size pattern))

                ;; Update total contributions count
                (var-set total-contributions (+ (var-get total-contributions) u1))
                
                ;; Add new snapshot for canvas evolution
                (map-set canvas-snapshots
                    { snapshot-id: (var-get total-contributions) }
                    { contributor: contributor, color: color, size: size, pattern: pattern })

                ;; Log the snapshot minting
                (emit-event (snapshot-minted (var-get total-contributions) contributor))

                ;; Return success response
                (ok contributor)
            )
            ;; Return error if already contributed
            (err ERR_ALREADY_CONTRIBUTED)
        )
    )
)

;; Function: View current canvas snapshot
(define-read-only (get-current-snapshot)
    (let ((current-snapshot (var-get total-contributions)))
        (map-get? canvas-snapshots { snapshot-id: current-snapshot })
    )
)

;; Function: Mint snapshot NFT for a contributor
(define-public (mint-snapshot)
    (let ((contributor tx-sender)
          (snapshot-id (var-get total-contributions)))
        ;; Check if contributor exists in snapshots
        (if (is-some (map-get? canvas-snapshots { snapshot-id: snapshot-id }))
            (begin
                ;; Increment total snapshots
                (var-set total-snapshots (+ (var-get total-snapshots) u1))

                ;; Log the minting event
                (emit-event (snapshot-minted snapshot-id contributor))

                ;; Return snapshot details
                (ok { snapshot-id: snapshot-id, contributor: contributor })
            )
            ;; Return error if snapshot doesn't exist
            (err ERR_NOT_AUTHORIZED)
        )
    )
)

;; Function: Contribute funds to the treasury
(define-public (contribute-funds (amount uint))
    (if (> amount u0)
        (begin
            ;; Add to treasury
            (var-set treasury (+ (var-get treasury) amount))
            (ok (var-get treasury))
        )
        (err ERR_INVALID_AMOUNT)
    )
)

;; Function: Distribute funds among contributors
(define-public (distribute-funds)
    (let ((total-balance (var-get treasury))
          (total-contributors (var-get total-contributions)))
        (if (> total-balance u0)
            (begin
                (map (lambda (contributor)
                        (let ((share (/ total-balance total-contributors)))
                            ;; Update each contributor's share
                            (map-set revenue-share { contributor: contributor } { amount: share })
                            (emit-event (funds-distributed contributor share))
                        )
                    )
                    (map-keys contributors)
                )
                ;; Reset treasury after distribution
                (var-set treasury u0)
                (ok "Funds distributed successfully")
            )
            (err ERR_NO_BALANCE)
        )
    )
)

;; Function: Get individual revenue share
(define-read-only (get-revenue-share (contributor principal))
    (map-get? revenue-share { contributor: contributor })
)

;; Function: View all contributions
(define-read-only (get-all-contributions)
    (map-keys contributors)
)

;; Function: View canvas evolution history
(define-read-only (get-canvas-evolution)
    (let ((total (var-get total-contributions)))
        (map (lambda (id)
                (map-get? canvas-snapshots { snapshot-id: id })
              )
             (range u1 total)
        )
    )
)
