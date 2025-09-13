(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-not-authorized (err u105))
(define-constant err-invalid-blood-type (err u106))
(define-constant err-donation-too-recent (err u107))

(define-data-var donation-counter uint u0)
(define-data-var reward-per-donation uint u100)
(define-data-var min-donation-interval uint u144)

(define-map donors principal {
    total-donations: uint,
    last-donation-block: uint,
    blood-type: (string-ascii 3),
    verified: bool,
    total-rewards: uint
})

(define-map donations uint {
    donor: principal,
    blood-type: (string-ascii 3),
    donation-date: uint,
    verified: bool,
    hospital: principal,
    reward-claimed: bool
})

(define-map hospitals principal {
    name: (string-ascii 50),
    verified: bool,
    total-donations-processed: uint
})

(define-map nft-badges uint {
    owner: principal,
    badge-type: (string-ascii 20),
    donation-count: uint,
    minted-at: uint
})

(define-data-var next-badge-id uint u1)

(define-public (register-donor (blood-type (string-ascii 3)))
    (let ((donor tx-sender))
        (asserts! (is-valid-blood-type blood-type) err-invalid-blood-type)
        (asserts! (is-none (map-get? donors donor)) err-already-exists)
        (ok (map-set donors donor {
            total-donations: u0,
            last-donation-block: u0,
            blood-type: blood-type,
            verified: false,
            total-rewards: u0
        }))
    )
)

(define-public (register-hospital (name (string-ascii 50)))
    (let ((hospital tx-sender))
        (asserts! (is-none (map-get? hospitals hospital)) err-already-exists)
        (ok (map-set hospitals hospital {
            name: name,
            verified: false,
            total-donations-processed: u0
        }))
    )
)

(define-public (verify-hospital (hospital principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? hospitals hospital)) err-not-found)
        (ok (map-set hospitals hospital 
            (merge (unwrap-panic (map-get? hospitals hospital)) {verified: true})
        ))
    )
)

(define-public (record-donation (donor principal) (blood-type (string-ascii 3)))
    (let (
        (hospital tx-sender)
        (donation-id (+ (var-get donation-counter) u1))
        (current-block stacks-block-height)
        (donor-data (unwrap! (map-get? donors donor) err-not-found))
        (hospital-data (unwrap! (map-get? hospitals hospital) err-not-found))
    )
        (asserts! (get verified hospital-data) err-not-authorized)
        (asserts! (is-valid-blood-type blood-type) err-invalid-blood-type)
        (asserts! (>= current-block (+ (get last-donation-block donor-data) (var-get min-donation-interval))) err-donation-too-recent)
        
        (map-set donations donation-id {
            donor: donor,
            blood-type: blood-type,
            donation-date: current-block,
            verified: false,
            hospital: hospital,
            reward-claimed: false
        })
        
        (map-set donors donor (merge donor-data {
            last-donation-block: current-block,
            total-donations: (+ (get total-donations donor-data) u1)
        }))
        
        (map-set hospitals hospital (merge hospital-data {
            total-donations-processed: (+ (get total-donations-processed hospital-data) u1)
        }))
        
        (var-set donation-counter donation-id)
        (ok donation-id)
    )
)

(define-public (verify-donation (donation-id uint))
    (let (
        (donation-data (unwrap! (map-get? donations donation-id) err-not-found))
        (donor (get donor donation-data))
        (donor-data (unwrap! (map-get? donors donor) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set donations donation-id (merge donation-data {verified: true}))
        (map-set donors donor (merge donor-data {verified: true}))
        (try! (check-and-mint-badge donor))
        (ok true)
    )
)

(define-public (claim-reward (donation-id uint))
    (let (
        (donation-data (unwrap! (map-get? donations donation-id) err-not-found))
        (donor (get donor donation-data))
        (donor-data (unwrap! (map-get? donors donor) err-not-found))
        (reward-amount (var-get reward-per-donation))
    )
        (asserts! (is-eq tx-sender donor) err-not-authorized)
        (asserts! (get verified donation-data) err-not-authorized)
        (asserts! (not (get reward-claimed donation-data)) err-already-exists)
        
        (map-set donations donation-id (merge donation-data {reward-claimed: true}))
        (map-set donors donor (merge donor-data {
            total-rewards: (+ (get total-rewards donor-data) reward-amount)
        }))
        
        (ok reward-amount)
    )
)

(define-private (check-and-mint-badge (donor principal))
    (let (
        (donor-data (unwrap! (map-get? donors donor) err-not-found))
        (donation-count (get total-donations donor-data))
        (badge-id (var-get next-badge-id))
    )
        (if (is-milestone-reached donation-count)
            (begin
                (map-set nft-badges badge-id {
                    owner: donor,
                    badge-type: (get-badge-type donation-count),
                    donation-count: donation-count,
                    minted-at: stacks-block-height
                })
                (var-set next-badge-id (+ badge-id u1))
                (ok badge-id)
            )
            (ok u0)
        )
    )
)

(define-public (transfer-badge (badge-id uint) (recipient principal))
    (let ((badge-data (unwrap! (map-get? nft-badges badge-id) err-not-found)))
        (asserts! (is-eq tx-sender (get owner badge-data)) err-not-authorized)
        (ok (map-set nft-badges badge-id (merge badge-data {owner: recipient})))
    )
)

(define-public (set-reward-amount (new-amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-amount u0) err-invalid-amount)
        (ok (var-set reward-per-donation new-amount))
    )
)

(define-public (set-donation-interval (new-interval uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set min-donation-interval new-interval))
    )
)

(define-read-only (get-donor-info (donor principal))
    (map-get? donors donor)
)

(define-read-only (get-donation-info (donation-id uint))
    (map-get? donations donation-id)
)

(define-read-only (get-hospital-info (hospital principal))
    (map-get? hospitals hospital)
)

(define-read-only (get-badge-info (badge-id uint))
    (map-get? nft-badges badge-id)
)

(define-read-only (get-total-donations)
    (var-get donation-counter)
)

(define-read-only (get-reward-per-donation)
    (var-get reward-per-donation)
)

(define-read-only (is-valid-blood-type (blood-type (string-ascii 3)))
    (or (is-eq blood-type "A+")
        (is-eq blood-type "A-")
        (is-eq blood-type "B+")
        (is-eq blood-type "B-")
        (is-eq blood-type "AB+")
        (is-eq blood-type "AB-")
        (is-eq blood-type "O+")
        (is-eq blood-type "O-"))
)

(define-read-only (is-milestone-reached (count uint))
    (or (is-eq count u1)
        (is-eq count u5)
        (is-eq count u10)
        (is-eq count u25)
        (is-eq count u50)
        (is-eq count u100))
)

(define-read-only (get-badge-type (count uint))
    (if (is-eq count u1) "First Donation"
        (if (is-eq count u5) "Regular Donor"
            (if (is-eq count u10) "Committed Donor"
                (if (is-eq count u25) "Hero Donor"
                    (if (is-eq count u50) "Super Hero"
                        (if (is-eq count u100) "Legend"
                            "Unknown"))))))
)

(define-read-only (get-donor-badges (donor principal))
    (let ((badges (list)))
        (fold check-badge-ownership (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) badges)
    )
)

(define-private (check-badge-ownership (badge-id uint) (acc (list 10 uint)))
    (match (map-get? nft-badges badge-id)
        badge-data (if (is-eq (get owner badge-data) tx-sender)
                      (unwrap-panic (as-max-len? (append acc badge-id) u10))
                      acc)
        acc
    )
)
