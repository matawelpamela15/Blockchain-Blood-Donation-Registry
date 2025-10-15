(define-constant err-not-found (err u400))
(define-constant err-already-claimed (err u401))
(define-constant err-insufficient-points (err u402))
(define-constant err-invalid-referral (err u403))
(define-constant err-self-referral (err u404))

(define-data-var points-per-donation uint u50)
(define-data-var points-per-referral uint u100)
(define-data-var streak-bonus-threshold uint u3)
(define-data-var streak-bonus-points uint u75)

(define-map loyalty-accounts principal {
    total-points: uint,
    redeemed-points: uint,
    current-streak: uint,
    longest-streak: uint,
    referrals-made: uint,
    last-donation-block: uint,
    tier: (string-ascii 10)
})

(define-map referrals {referrer: principal, referee: principal} {
    referred-at: uint,
    points-awarded: bool,
    referee-donated: bool
})

(define-map point-transactions uint {
    donor: principal,
    amount: uint,
    transaction-type: (string-ascii 20),
    timestamp: uint,
    description: (string-ascii 50)
})

(define-data-var transaction-counter uint u0)

(define-public (initialize-account)
    (let ((donor tx-sender))
        (asserts! (is-none (map-get? loyalty-accounts donor)) err-already-claimed)
        (ok (map-set loyalty-accounts donor {
            total-points: u0,
            redeemed-points: u0,
            current-streak: u0,
            longest-streak: u0,
            referrals-made: u0,
            last-donation-block: u0,
            tier: "bronze"
        }))
    )
)

(define-public (award-donation-points (donor principal))
    (let (
        (account (unwrap! (map-get? loyalty-accounts donor) err-not-found))
        (base-points (var-get points-per-donation))
        (new-streak (+ (get current-streak account) u1))
        (streak-bonus (if (>= new-streak (var-get streak-bonus-threshold)) 
                         (var-get streak-bonus-points) 
                         u0))
        (total-award (+ base-points streak-bonus))
        (new-total (+ (get total-points account) total-award))
    )
        (map-set loyalty-accounts donor (merge account {
            total-points: new-total,
            current-streak: new-streak,
            longest-streak: (if (> new-streak (get longest-streak account)) 
                               new-streak 
                               (get longest-streak account)),
            last-donation-block: stacks-block-height
        }))
        (log-transaction donor total-award "donation" "Points for donation")
        (ok total-award)
    )
)

(define-public (register-referral (referee principal))
    (let (
        (referrer tx-sender)
        (referral-key {referrer: referrer, referee: referee})
    )
        (asserts! (not (is-eq referrer referee)) err-self-referral)
        (asserts! (is-none (map-get? referrals referral-key)) err-already-claimed)
        (asserts! (is-some (map-get? loyalty-accounts referrer)) err-not-found)
        
        (map-set referrals referral-key {
            referred-at: stacks-block-height,
            points-awarded: false,
            referee-donated: false
        })
        (ok true)
    )
)

(define-public (complete-referral (referrer principal))
    (let (
        (referee tx-sender)
        (referral-key {referrer: referrer, referee: referee})
        (referral-data (unwrap! (map-get? referrals referral-key) err-not-found))
        (referrer-account (unwrap! (map-get? loyalty-accounts referrer) err-not-found))
        (referral-points (var-get points-per-referral))
    )
        (asserts! (not (get points-awarded referral-data)) err-already-claimed)
        
        (map-set referrals referral-key (merge referral-data {
            points-awarded: true,
            referee-donated: true
        }))
        
        (map-set loyalty-accounts referrer (merge referrer-account {
            total-points: (+ (get total-points referrer-account) referral-points),
            referrals-made: (+ (get referrals-made referrer-account) u1)
        }))
        
        (log-transaction referrer referral-points "referral" "Referral bonus")
        (ok referral-points)
    )
)

(define-public (redeem-points (amount uint) (purpose (string-ascii 50)))
    (let (
        (donor tx-sender)
        (account (unwrap! (map-get? loyalty-accounts donor) err-not-found))
        (available (- (get total-points account) (get redeemed-points account)))
    )
        (asserts! (>= available amount) err-insufficient-points)
        
        (map-set loyalty-accounts donor (merge account {
            redeemed-points: (+ (get redeemed-points account) amount)
        }))
        
        (log-transaction donor amount "redemption" purpose)
        (ok true)
    )
)

(define-private (log-transaction (donor principal) (amount uint) (tx-type (string-ascii 20)) (desc (string-ascii 50)))
    (let ((tx-id (+ (var-get transaction-counter) u1)))
        (map-set point-transactions tx-id {
            donor: donor,
            amount: amount,
            transaction-type: tx-type,
            timestamp: stacks-block-height,
            description: desc
        })
        (var-set transaction-counter tx-id)
        tx-id
    )
)

(define-read-only (get-loyalty-account (donor principal))
    (map-get? loyalty-accounts donor)
)

(define-read-only (get-available-points (donor principal))
    (match (map-get? loyalty-accounts donor)
        account (ok (- (get total-points account) (get redeemed-points account)))
        err-not-found
    )
)

(define-read-only (get-referral-status (referrer principal) (referee principal))
    (map-get? referrals {referrer: referrer, referee: referee})
)

(define-read-only (get-transaction (tx-id uint))
    (map-get? point-transactions tx-id)
)
