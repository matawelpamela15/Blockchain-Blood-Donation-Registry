(define-constant err-request-not-found (err u108))
(define-constant err-request-expired (err u109))
(define-constant err-already-responded (err u110))
(define-constant err-incompatible-blood-type (err u111))
(define-constant err-not-authorized (err u112))
(define-constant err-already-exists (err u113))

(define-data-var emergency-request-counter uint u0)
(define-data-var emergency-request-duration uint u1440)

(define-map emergency-requests uint {
    hospital: principal,
    blood-type: (string-ascii 3),
    units-needed: uint,
    priority: (string-ascii 10),
    created-at: uint,
    expires-at: uint,
    fulfilled: bool,
    responses: uint
})

(define-map emergency-responses {request-id: uint, donor: principal} {
    responded-at: uint,
    available-units: uint,
    contact-info: (string-ascii 50)
})

(define-public (create-emergency-request (blood-type (string-ascii 3)) (units-needed uint) (priority (string-ascii 10)))
    (let (
        (hospital tx-sender)
        (request-id (+ (var-get emergency-request-counter) u1))
        (current-block stacks-block-height)
    )
        (asserts! (> units-needed u0) (err u100))
        (asserts! (or (is-eq blood-type "A+") 
                     (is-eq blood-type "A-")
                     (is-eq blood-type "B+")
                     (is-eq blood-type "B-")
                     (is-eq blood-type "O+")
                     (is-eq blood-type "O-")
                     (is-eq blood-type "AB+")
                     (is-eq blood-type "AB-")) (err u101))
        
        (map-set emergency-requests request-id {
            hospital: hospital,
            blood-type: blood-type,
            units-needed: units-needed,
            priority: priority,
            created-at: current-block,
            expires-at: (+ current-block (var-get emergency-request-duration)),
            fulfilled: false,
            responses: u0
        })
        
        (var-set emergency-request-counter request-id)
        (ok request-id)
    )
)

(define-public (respond-to-emergency (request-id uint) (available-units uint) (contact-info (string-ascii 50)))
    (let (
        (donor tx-sender)
        (request-data (unwrap! (map-get? emergency-requests request-id) err-request-not-found))
        (response-key {request-id: request-id, donor: donor})
    )
        (asserts! (< stacks-block-height (get expires-at request-data)) err-request-expired)
        (asserts! (not (get fulfilled request-data)) (err u102))
        (asserts! (is-none (map-get? emergency-responses response-key)) err-already-responded)
        (asserts! (> available-units u0) (err u103))
        
        (map-set emergency-responses response-key {
            responded-at: stacks-block-height,
            available-units: available-units,
            contact-info: contact-info
        })
        
        (map-set emergency-requests request-id (merge request-data {
            responses: (+ (get responses request-data) u1)
        }))
        
        (ok true)
    )
)

(define-public (fulfill-emergency-request (request-id uint))
    (let ((request-data (unwrap! (map-get? emergency-requests request-id) err-request-not-found)))
        (asserts! (is-eq tx-sender (get hospital request-data)) err-not-authorized)
        (asserts! (not (get fulfilled request-data)) err-already-exists)
        
        (ok (map-set emergency-requests request-id (merge request-data {fulfilled: true})))
    )
) 

(define-read-only (get-emergency-request (request-id uint))
    (map-get? emergency-requests request-id)
)

(define-read-only (get-emergency-response (request-id uint) (donor principal))
    (map-get? emergency-responses {request-id: request-id, donor: donor})
)

(define-read-only (is-compatible-blood-type (donor-type (string-ascii 3)) (needed-type (string-ascii 3)))
    (or (is-eq donor-type needed-type)
        (is-eq donor-type "O-")
        (and (is-eq needed-type "AB+") (or (is-eq donor-type "A+") (is-eq donor-type "B+") (is-eq donor-type "AB-")))
        (and (is-eq needed-type "AB-") (or (is-eq donor-type "A-") (is-eq donor-type "B-")))
        (and (is-eq needed-type "A+") (or (is-eq donor-type "A-") (is-eq donor-type "O+")))
        (and (is-eq needed-type "B+") (or (is-eq donor-type "B-") (is-eq donor-type "O+")))
        (and (is-eq needed-type "A-") (is-eq donor-type "O-"))
        (and (is-eq needed-type "B-") (is-eq donor-type "O-"))
        (and (is-eq needed-type "O+") (is-eq donor-type "O-")))
)
