(define-constant err-not-authorized (err u200))
(define-constant err-unit-not-found (err u201))
(define-constant err-unit-expired (err u202))
(define-constant err-insufficient-units (err u203))
(define-constant err-invalid-expiry (err u204))
(define-constant err-location-not-found (err u205))

(define-data-var unit-counter uint u0)
(define-data-var blood-shelf-life uint u5040)

(define-map blood-units uint {
    blood-type: (string-ascii 3),
    location: principal,
    collected-at: uint,
    expires-at: uint,
    status: (string-ascii 10),
    donor-id: (optional principal)
})

(define-map location-inventory {location: principal, blood-type: (string-ascii 3)} {
    total-units: uint,
    available-units: uint,
    expired-units: uint,
    last-updated: uint
})

(define-map location-stats principal {
    total-received: uint,
    total-distributed: uint,
    total-expired: uint,
    efficiency-score: uint
})

(define-public (register-blood-unit (blood-type (string-ascii 3)) (donor-id (optional principal)))
    (let (
        (location tx-sender)
        (unit-id (+ (var-get unit-counter) u1))
        (current-block stacks-block-height)
        (expiry-block (+ current-block (var-get blood-shelf-life)))
        (inventory-key {location: location, blood-type: blood-type})
        (current-inventory (default-to {total-units: u0, available-units: u0, expired-units: u0, last-updated: u0} 
                                      (map-get? location-inventory inventory-key)))
    )
        (map-set blood-units unit-id {
            blood-type: blood-type,
            location: location,
            collected-at: current-block,
            expires-at: expiry-block,
            status: "available",
            donor-id: donor-id
        })
        
        (map-set location-inventory inventory-key {
            total-units: (+ (get total-units current-inventory) u1),
            available-units: (+ (get available-units current-inventory) u1),
            expired-units: (get expired-units current-inventory),
            last-updated: current-block
        })
        
        (var-set unit-counter unit-id)
        (ok unit-id)
    )
)

(define-public (transfer-blood-unit (unit-id uint) (destination principal))
    (let (
        (unit-data (unwrap! (map-get? blood-units unit-id) err-unit-not-found))
        (source-location (get location unit-data))
        (blood-type (get blood-type unit-data))
        (source-key {location: source-location, blood-type: blood-type})
        (dest-key {location: destination, blood-type: blood-type})
        (source-inventory (unwrap! (map-get? location-inventory source-key) err-location-not-found))
        (dest-inventory (default-to {total-units: u0, available-units: u0, expired-units: u0, last-updated: u0}
                                   (map-get? location-inventory dest-key)))
    )
        (asserts! (is-eq tx-sender source-location) err-not-authorized)
        (asserts! (is-eq (get status unit-data) "available") err-unit-expired)
        (asserts! (> (get available-units source-inventory) u0) err-insufficient-units)
        
        (map-set blood-units unit-id (merge unit-data {location: destination}))
        
        (map-set location-inventory source-key {
            total-units: (- (get total-units source-inventory) u1),
            available-units: (- (get available-units source-inventory) u1),
            expired-units: (get expired-units source-inventory),
            last-updated: stacks-block-height
        })
        
        (map-set location-inventory dest-key {
            total-units: (+ (get total-units dest-inventory) u1),
            available-units: (+ (get available-units dest-inventory) u1),
            expired-units: (get expired-units dest-inventory),
            last-updated: stacks-block-height
        })
        
        (ok true)
    )
)

(define-public (mark-unit-used (unit-id uint))
    (let ((unit-data (unwrap! (map-get? blood-units unit-id) err-unit-not-found)))
        (asserts! (is-eq tx-sender (get location unit-data)) err-not-authorized)
        (asserts! (is-eq (get status unit-data) "available") err-unit-expired)
        (ok (map-set blood-units unit-id (merge unit-data {status: "used"})))
    )
)

(define-read-only (get-unit-info (unit-id uint))
    (map-get? blood-units unit-id)
)

(define-read-only (get-location-inventory (location principal) (blood-type (string-ascii 3)))
    (map-get? location-inventory {location: location, blood-type: blood-type})
)

(define-read-only (check-expiry-status (unit-id uint))
    (match (map-get? blood-units unit-id)
        unit-data (if (>= stacks-block-height (get expires-at unit-data))
                     "expired"
                     (get status unit-data))
        "not-found"
    )
)

(define-read-only (get-available-units (location principal) (blood-type (string-ascii 3)))
    (match (map-get? location-inventory {location: location, blood-type: blood-type})
        inventory (get available-units inventory)
        u0
    )
)