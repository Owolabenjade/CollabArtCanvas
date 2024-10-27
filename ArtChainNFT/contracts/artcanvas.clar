(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_ALREADY_CONTRIBUTED u101)
(define-constant ERR_NO_BALANCE u102)
(define-constant ERR_INVALID_AMOUNT u103)
(define-constant ERR_INVALID_COLOR_SIZE u104)
(define-constant ERR_INVALID_PATTERN_SIZE u105) 
(define-constant ERR_INVALID_SIZE_VALUE u106)

;; Contributors map to store contribution details
(define-map contributors
   { contributor: principal }
   {
       color: (optional (buff 32)),
       size: (optional uint),
       pattern: (optional (buff 32))
   })

;; Canvas snapshots map to track each contribution's impact
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
(define-data-var last-distributed-index uint u0)

;; New data variable to store the list of contributors with explicit length check
(define-data-var contributors-list (list 100 principal) (list))

;; Record of revenue share for each contributor
(define-map revenue-share
   { contributor: principal }
   { amount: uint })

;; Helper function to validate buff length
(define-private (validate-buff-32 (input (optional (buff 32))))
   (match input
       buff-val (< (len buff-val) u33)
       true))

;; Helper function to validate size
(define-private (validate-size (input (optional uint)))
   (match input
       size-val (and (>= size-val u1) (<= size-val u100))
       true))

;; Helper function to safely append to the contributors list
(define-private (safe-append-contributor (current-list (list 100 principal)) (new-contributor principal))
   (let ((current-length (len current-list)))
       (if (< current-length u99)  ;; Check if we have room for one more (99 < 100)
           (unwrap-panic (as-max-len? 
               (append current-list new-contributor)
               u100))
           current-list))) ;; If full, return unchanged list

;; Function: Contribute to the canvas with validation
(define-public (contribute (color (optional (buff 32))) (size (optional uint)) (pattern (optional (buff 32))))
   (let 
       ((contributor tx-sender))
       ;; Validate inputs first
       (asserts! (validate-buff-32 color) (err ERR_INVALID_COLOR_SIZE))
       (asserts! (validate-buff-32 pattern) (err ERR_INVALID_PATTERN_SIZE))
       (asserts! (validate-size size) (err ERR_INVALID_SIZE_VALUE))
       
       ;; Check if contributor already contributed
       (if (is-none (map-get? contributors { contributor: contributor }))
           (begin
               ;; Log contribution in contributors map
               (map-set contributors
                   { contributor: contributor }
                   { color: color, size: size, pattern: pattern })
               
               ;; Safely add contributor to the list
               (var-set contributors-list 
                   (safe-append-contributor (var-get contributors-list) contributor))
               
               ;; Update total contributions count
               (var-set total-contributions (+ (var-get total-contributions) u1))
               
               ;; Add new snapshot for canvas evolution
               (map-set canvas-snapshots
                   { snapshot-id: (var-get total-contributions) }
                   { contributor: contributor, color: color, size: size, pattern: pattern })

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

;; Function: Distribute funds to contributors in a stepwise manner
(define-public (distribute-funds-step)
   (let ((total-balance (var-get treasury))
         (total-contributors (var-get total-contributions))
         (current-index (var-get last-distributed-index)))
       
       ;; Check if there's balance and more contributors to process
       (if (and (> total-balance u0) 
                (< current-index total-contributors))
           
           ;; Process current contributor
           (let ((share (/ total-balance total-contributors)))
               ;; Check if tx-sender is a valid contributor
               (if (is-some (map-get? contributors { contributor: tx-sender }))
                   (begin
                       ;; Update the contributor's revenue share
                       (map-set revenue-share 
                           { contributor: tx-sender } 
                           { amount: share })
                       
                       ;; Move to next contributor
                       (var-set last-distributed-index (+ current-index u1))
                       
                       ;; Return success response
                       (ok {
                           status: "success",
                           message: "Distributed to contributor",
                           contributor: (some tx-sender)
                       })
                   )
                   (err ERR_NOT_AUTHORIZED)
               )
           )
           
           ;; If we've processed all contributors or no balance
           (if (>= current-index total-contributors)
               (begin
                   ;; Reset treasury and distribution index
                   (var-set treasury u0)
                   (var-set last-distributed-index u0)
                   ;; Return success response
                   (ok {
                       status: "success",
                       message: "All funds distributed",
                       contributor: none
                   })
               )
               (err ERR_NO_BALANCE)
           )
       )
   )
)

;; Function: Get individual revenue share
(define-read-only (get-revenue-share (contributor principal))
   (map-get? revenue-share { contributor: contributor })
)

;; Function: View total number of contributions
(define-read-only (get-all-contributions)
   (var-get total-contributions)
)

;; Helper to get a single snapshot without list accumulation
(define-private (get-snapshot-at-index 
   (index uint) 
   (acc (optional {
       contributor: principal,
       color: (optional (buff 32)),
       size: (optional uint),
       pattern: (optional (buff 32))
   }))
)
   (let ((total (var-get total-contributions)))
       (if (<= index total)
           (map-get? canvas-snapshots { snapshot-id: index })
           acc
       )
   )
)

;; Function: View canvas evolution history - simplified version
(define-read-only (get-canvas-evolution)
   (let ((total (var-get total-contributions)))
       (if (<= total u0)
           (ok (list))
           (let ((result 
               (list 
                   (get-snapshot-at-index u1 none)
                   (get-snapshot-at-index u2 none)
                   (get-snapshot-at-index u3 none)
                   (get-snapshot-at-index u4 none)
                   (get-snapshot-at-index u5 none))))
               (ok result)))))