;; Healthcare Crowdfunding Platform Smart Contract
;; This contract enables transparent crowdfunding for medical treatments
;; with automated fund allocation and comprehensive tracking

;; Error constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u101))
(define-constant ERR-CAMPAIGN-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-GOAL-AMOUNT (err u103))
(define-constant ERR-INVALID-DURATION (err u104))
(define-constant ERR-CAMPAIGN-EXPIRED (err u105))
(define-constant ERR-CAMPAIGN-NOT-ACTIVE (err u106))
(define-constant ERR-INSUFFICIENT-FUNDS (err u107))
(define-constant ERR-INVALID-AMOUNT (err u108))
(define-constant ERR-WITHDRAWAL-NOT-ALLOWED (err u109))
(define-constant ERR-REFUND-NOT-AVAILABLE (err u110))
(define-constant ERR-ALREADY-CONTRIBUTED (err u111))
(define-constant ERR-NO-CONTRIBUTION-FOUND (err u112))
(define-constant ERR-GOAL-ALREADY-REACHED (err u113))
(define-constant ERR-INVALID-VERIFICATION-STATUS (err u114))
(define-constant ERR-INVALID-STRING-INPUT (err u115))

;; Contract owner for administrative functions
(define-constant CONTRACT-OWNER tx-sender)

;; Minimum and maximum campaign parameters for validation
(define-constant MIN-GOAL-AMOUNT u1000000) ;; 1 STX minimum goal
(define-constant MAX-GOAL-AMOUNT u1000000000000) ;; 1M STX maximum goal
(define-constant MIN-DURATION u144) ;; 1 day minimum (144 blocks)
(define-constant MAX-DURATION u144000) ;; ~1000 days maximum

;; Campaign status constants for state management
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-EXPIRED u3)
(define-constant STATUS-CANCELLED u4)

;; Verification status constants for medical validation
(define-constant VERIFICATION-PENDING u1)
(define-constant VERIFICATION-APPROVED u2)
(define-constant VERIFICATION-REJECTED u3)

;; Data structure for individual campaigns
(define-map campaigns 
  { campaign-id: uint }
  {
    creator: principal,           ;; Address of the campaign creator/patient
    title: (string-ascii 100),   ;; Campaign title
    description: (string-ascii 500), ;; Medical condition description
    goal-amount: uint,           ;; Target funding amount in microSTX
    raised-amount: uint,         ;; Current amount raised
    start-block: uint,           ;; Block when campaign started
    end-block: uint,             ;; Block when campaign expires
    status: uint,                ;; Current campaign status
    verification-status: uint,   ;; Medical verification status
    total-contributors: uint,    ;; Number of unique contributors
    withdrawal-count: uint       ;; Number of withdrawals made
  }
)

;; Track individual contributions for transparency and refunds
(define-map contributions
  { campaign-id: uint, contributor: principal }
  { amount: uint, block-height: uint }
)

;; Store campaign IDs created by each user for easy lookup
(define-map user-campaigns
  { creator: principal }
  { campaign-ids: (list 50 uint) }
)

;; Track total contributions per user across all campaigns
(define-map user-total-contributions
  { user: principal }
  { total-amount: uint, campaigns-count: uint }
)

;; Platform statistics for transparency
(define-data-var total-campaigns uint u0)
(define-data-var total-funds-raised uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var next-campaign-id uint u1)

;; Events for external tracking and notifications
(define-data-var last-event-id uint u0)

;; Helper function to validate string inputs
(define-private (is-valid-string-ascii (input (string-ascii 500)))
  (let ((input-len (len input)))
    (and (> input-len u0) (<= input-len u500))
  )
)

;; Helper function to validate title length
(define-private (is-valid-title (title (string-ascii 100)))
  (let ((title-len (len title)))
    (and (> title-len u0) (<= title-len u100))
  )
)

;; Helper function to validate campaign ID exists
(define-private (campaign-exists (campaign-id uint))
  (is-some (map-get? campaigns { campaign-id: campaign-id }))
)

;; Create a new medical crowdfunding campaign
;; Parameters: title, description, goal amount, and duration in blocks
(define-public (create-campaign 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (goal-amount uint)
    (duration uint))
  (let (
    (campaign-id (var-get next-campaign-id))
    (current-block block-height)
  )
    ;; Validate string inputs
    (asserts! (is-valid-title title) ERR-INVALID-STRING-INPUT)
    (asserts! (is-valid-string-ascii description) ERR-INVALID-STRING-INPUT)
    
    ;; Validate numeric parameters
    (asserts! (>= goal-amount MIN-GOAL-AMOUNT) ERR-INVALID-GOAL-AMOUNT)
    (asserts! (<= goal-amount MAX-GOAL-AMOUNT) ERR-INVALID-GOAL-AMOUNT)
    (asserts! (>= duration MIN-DURATION) ERR-INVALID-DURATION)
    (asserts! (<= duration MAX-DURATION) ERR-INVALID-DURATION)
    
    ;; Ensure campaign doesn't already exist (should not happen with auto-increment)
    (asserts! (is-none (map-get? campaigns { campaign-id: campaign-id })) 
              ERR-CAMPAIGN-ALREADY-EXISTS)
    
    ;; Create the campaign record
    (map-set campaigns 
      { campaign-id: campaign-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        goal-amount: goal-amount,
        raised-amount: u0,
        start-block: current-block,
        end-block: (+ current-block duration),
        status: STATUS-ACTIVE,
        verification-status: VERIFICATION-PENDING,
        total-contributors: u0,
        withdrawal-count: u0
      }
    )
    
    ;; Update user's campaign list
    (let (
      (current-campaigns (default-to (list) 
        (get campaign-ids (map-get? user-campaigns { creator: tx-sender }))))
    )
      (map-set user-campaigns
        { creator: tx-sender }
        { campaign-ids: (unwrap! (as-max-len? (append current-campaigns campaign-id) u50)
                                ERR-INVALID-AMOUNT) }
      )
    )
    
    ;; Update global counters
    (var-set total-campaigns (+ (var-get total-campaigns) u1))
    (var-set next-campaign-id (+ campaign-id u1))
    
    (ok campaign-id)
  )
)

;; Contribute funds to a specific campaign
;; Amount is automatically taken from the transaction value
(define-public (contribute-to-campaign (campaign-id uint) (amount uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) 
                      ERR-CAMPAIGN-NOT-FOUND))
    (current-contribution (map-get? contributions 
                          { campaign-id: campaign-id, contributor: tx-sender }))
  )
    ;; Validate campaign exists
    (asserts! (campaign-exists campaign-id) ERR-CAMPAIGN-NOT-FOUND)
    
    ;; Validate contribution parameters
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq (get status campaign) STATUS-ACTIVE) ERR-CAMPAIGN-NOT-ACTIVE)
    (asserts! (<= block-height (get end-block campaign)) ERR-CAMPAIGN-EXPIRED)
    (asserts! (< (get raised-amount campaign) (get goal-amount campaign)) 
              ERR-GOAL-ALREADY-REACHED)
    
    ;; Transfer funds from contributor to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Calculate new totals
    (let (
      (new-raised-amount (+ (get raised-amount campaign) amount))
      (is-new-contributor (is-none current-contribution))
      (new-contributor-count (if is-new-contributor 
                               (+ (get total-contributors campaign) u1)
                               (get total-contributors campaign)))
    )
      
      ;; Update campaign with new amounts
      (map-set campaigns
        { campaign-id: campaign-id }
        (merge campaign {
          raised-amount: new-raised-amount,
          total-contributors: new-contributor-count,
          status: (if (>= new-raised-amount (get goal-amount campaign))
                    STATUS-COMPLETED
                    STATUS-ACTIVE)
        })
      )
      
      ;; Record the contribution
      (map-set contributions
        { campaign-id: campaign-id, contributor: tx-sender }
        {
          amount: (+ amount (default-to u0 
                   (get amount current-contribution))),
          block-height: block-height
        }
      )
      
      ;; Update user's total contribution statistics
      (let (
        (user-stats (default-to { total-amount: u0, campaigns-count: u0 }
                    (map-get? user-total-contributions { user: tx-sender })))
      )
        (map-set user-total-contributions
          { user: tx-sender }
          {
            total-amount: (+ (get total-amount user-stats) amount),
            campaigns-count: (if is-new-contributor
                              (+ (get campaigns-count user-stats) u1)
                              (get campaigns-count user-stats))
          }
        )
      )
      
      ;; Update global statistics
      (var-set total-funds-raised (+ (var-get total-funds-raised) amount))
      
      (ok new-raised-amount)
    )
  )
)

;; Allow campaign creators to withdraw funds (partial withdrawals supported)
(define-public (withdraw-funds (campaign-id uint) (amount uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) 
                      ERR-CAMPAIGN-NOT-FOUND))
  )
    ;; Validate campaign exists
    (asserts! (campaign-exists campaign-id) ERR-CAMPAIGN-NOT-FOUND)
    
    ;; Validate withdrawal permissions and conditions
    (asserts! (is-eq tx-sender (get creator campaign)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (get raised-amount campaign) amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (or (is-eq (get status campaign) STATUS-COMPLETED)
                  (is-eq (get verification-status campaign) VERIFICATION-APPROVED))
              ERR-WITHDRAWAL-NOT-ALLOWED)
    
    ;; Calculate platform fee (only on withdrawals to encourage completion)
    (let (
      (platform-fee (/ (* amount (var-get platform-fee-rate)) u10000))
      (net-amount (- amount platform-fee))
    )
      
      ;; Transfer net amount to campaign creator
      (try! (as-contract (stx-transfer? net-amount tx-sender (get creator campaign))))
      
      ;; Transfer platform fee to contract owner
      (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT-OWNER)))
      
      ;; Update campaign to reflect withdrawal
      (map-set campaigns
        { campaign-id: campaign-id }
        (merge campaign {
          raised-amount: (- (get raised-amount campaign) amount),
          withdrawal-count: (+ (get withdrawal-count campaign) u1)
        })
      )
      
      (ok net-amount)
    )
  )
)

;; Allow contributors to request refunds for unsuccessful campaigns
(define-public (request-refund (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) 
                      ERR-CAMPAIGN-NOT-FOUND))
    (contribution (unwrap! (map-get? contributions 
                          { campaign-id: campaign-id, contributor: tx-sender })
                          ERR-NO-CONTRIBUTION-FOUND))
  )
    ;; Validate campaign exists
    (asserts! (campaign-exists campaign-id) ERR-CAMPAIGN-NOT-FOUND)
    
    ;; Validate refund conditions
    (asserts! (> (get amount contribution) u0) ERR-INVALID-AMOUNT)
    (asserts! (or (> block-height (get end-block campaign))
                  (is-eq (get status campaign) STATUS-CANCELLED)
                  (is-eq (get verification-status campaign) VERIFICATION-REJECTED))
              ERR-REFUND-NOT-AVAILABLE)
    (asserts! (< (get raised-amount campaign) (get goal-amount campaign))
              ERR-REFUND-NOT-AVAILABLE)
    
    ;; Process refund
    (let (
      (refund-amount (get amount contribution))
    )
      ;; Transfer refund to contributor
      (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
      
      ;; Remove contribution record
      (map-delete contributions { campaign-id: campaign-id, contributor: tx-sender })
      
      ;; Update campaign statistics
      (map-set campaigns
        { campaign-id: campaign-id }
        (merge campaign {
          raised-amount: (- (get raised-amount campaign) refund-amount),
          total-contributors: (- (get total-contributors campaign) u1)
        })
      )
      
      (ok refund-amount)
    )
  )
)

;; Administrative function to update campaign verification status
(define-public (update-verification-status (campaign-id uint) (new-status uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) 
                      ERR-CAMPAIGN-NOT-FOUND))
  )
    ;; Validate campaign exists
    (asserts! (campaign-exists campaign-id) ERR-CAMPAIGN-NOT-FOUND)
    
    ;; Only contract owner can update verification status
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (or (is-eq new-status VERIFICATION-PENDING)
                  (is-eq new-status VERIFICATION-APPROVED)
                  (is-eq new-status VERIFICATION-REJECTED))
              ERR-INVALID-VERIFICATION-STATUS)
    
    ;; Update verification status
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { verification-status: new-status })
    )
    
    (ok new-status)
  )
)

;; Administrative function to cancel a campaign (emergency use)
(define-public (cancel-campaign (campaign-id uint))
  (let (
    (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) 
                      ERR-CAMPAIGN-NOT-FOUND))
  )
    ;; Validate campaign exists
    (asserts! (campaign-exists campaign-id) ERR-CAMPAIGN-NOT-FOUND)
    
    ;; Only contract owner or campaign creator can cancel
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                  (is-eq tx-sender (get creator campaign)))
              ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get status campaign) STATUS-ACTIVE) ERR-CAMPAIGN-NOT-ACTIVE)
    
    ;; Update campaign status to cancelled
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { status: STATUS-CANCELLED })
    )
    
    (ok campaign-id)
  )
)

;; Read-only function to get complete campaign information
(define-read-only (get-campaign-info (campaign-id uint))
  (if (campaign-exists campaign-id)
    (map-get? campaigns { campaign-id: campaign-id })
    none
  )
)

;; Read-only function to get contribution details for a specific user
(define-read-only (get-user-contribution (campaign-id uint) (user principal))
  (if (campaign-exists campaign-id)
    (map-get? contributions { campaign-id: campaign-id, contributor: user })
    none
  )
)

;; Read-only function to get all campaigns created by a user
(define-read-only (get-user-campaigns (user principal))
  (map-get? user-campaigns { creator: user })
)

;; Read-only function to get user's total contribution statistics
(define-read-only (get-user-stats (user principal))
  (map-get? user-total-contributions { user: user })
)

;; Read-only function to get platform statistics
(define-read-only (get-platform-stats)
  {
    total-campaigns: (var-get total-campaigns),
    total-funds-raised: (var-get total-funds-raised),
    platform-fee-rate: (var-get platform-fee-rate),
    next-campaign-id: (var-get next-campaign-id)
  }
)

;; Read-only function to check if a campaign is currently active and accepting contributions
(define-read-only (is-campaign-active (campaign-id uint))
  (if (campaign-exists campaign-id)
    (match (map-get? campaigns { campaign-id: campaign-id })
      campaign (and (is-eq (get status campaign) STATUS-ACTIVE)
                    (<= block-height (get end-block campaign))
                    (< (get raised-amount campaign) (get goal-amount campaign)))
      false
    )
    false
  )
)

;; Read-only function to calculate remaining time for a campaign
(define-read-only (get-campaign-time-remaining (campaign-id uint))
  (if (campaign-exists campaign-id)
    (match (map-get? campaigns { campaign-id: campaign-id })
      campaign (if (> (get end-block campaign) block-height)
                 (some (- (get end-block campaign) block-height))
                 (some u0))
      none
    )
    none
  )
)

;; Read-only function to get campaign progress percentage (scaled by 100)
(define-read-only (get-campaign-progress (campaign-id uint))
  (if (campaign-exists campaign-id)
    (match (map-get? campaigns { campaign-id: campaign-id })
      campaign (some (/ (* (get raised-amount campaign) u10000) (get goal-amount campaign)))
      none
    )
    none
  )
)

;; Administrative function to update platform fee rate (only contract owner)
(define-public (update-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= new-rate u1000) ERR-INVALID-AMOUNT) ;; Max 10% fee
    (var-set platform-fee-rate new-rate)
    (ok new-rate)
  )
)