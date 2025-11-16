(define-constant err-campaign-not-found (err u500))
(define-constant err-campaign-ended (err u501))
(define-constant err-campaign-active (err u502))
(define-constant err-not-organizer (err u503))
(define-constant err-invalid-duration (err u504))
(define-constant err-already-participated (err u505))

(define-data-var campaign-counter uint u0)

(define-map campaigns uint {
    organizer: principal,
    title: (string-ascii 50),
    blood-type-target: (optional (string-ascii 3)),
    goal-units: uint,
    units-collected: uint,
    multiplier: uint,
    start-block: uint,
    end-block: uint,
    active: bool,
    total-participants: uint
})

(define-map campaign-participations {campaign-id: uint, donor: principal} {
    units-donated: uint,
    joined-at: uint,
    bonus-earned: uint
})

(define-map campaign-leaderboard {campaign-id: uint, rank: uint} {
    donor: principal,
    units: uint
})

(define-public (create-campaign 
    (title (string-ascii 50))
    (blood-type-target (optional (string-ascii 3)))
    (goal-units uint)
    (multiplier uint)
    (duration-blocks uint))
    (let (
        (campaign-id (+ (var-get campaign-counter) u1))
        (current-block stacks-block-height)
    )
        (asserts! (> duration-blocks u0) err-invalid-duration)
        (asserts! (> goal-units u0) err-invalid-duration)
        (map-set campaigns campaign-id {
            organizer: tx-sender,
            title: title,
            blood-type-target: blood-type-target,
            goal-units: goal-units,
            units-collected: u0,
            multiplier: multiplier,
            start-block: current-block,
            end-block: (+ current-block duration-blocks),
            active: true,
            total-participants: u0
        })
        (var-set campaign-counter campaign-id)
        (ok campaign-id)
    )
)

(define-public (participate-in-campaign (campaign-id uint) (units uint))
    (let (
        (campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
        (participation-key {campaign-id: campaign-id, donor: tx-sender})
        (current-participation (map-get? campaign-participations participation-key))
    )
        (asserts! (get active campaign) err-campaign-ended)
        (asserts! (< stacks-block-height (get end-block campaign)) err-campaign-ended)
        (match current-participation
            existing (map-set campaign-participations participation-key {
                units-donated: (+ (get units-donated existing) units),
                joined-at: (get joined-at existing),
                bonus-earned: (+ (get bonus-earned existing) (* units (get multiplier campaign)))
            })
            (begin
                (map-set campaign-participations participation-key {
                    units-donated: units,
                    joined-at: stacks-block-height,
                    bonus-earned: (* units (get multiplier campaign))
                })
                (map-set campaigns campaign-id (merge campaign {
                    total-participants: (+ (get total-participants campaign) u1)
                }))
            )
        )
        (map-set campaigns campaign-id (merge campaign {
            units-collected: (+ (get units-collected campaign) units)
        }))
        (ok (* units (get multiplier campaign)))
    )
)

(define-public (end-campaign (campaign-id uint))
    (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found)))
        (asserts! (is-eq tx-sender (get organizer campaign)) err-not-organizer)
        (asserts! (get active campaign) err-campaign-ended)
        (ok (map-set campaigns campaign-id (merge campaign {active: false})))
    )
)

(define-read-only (get-campaign-info (campaign-id uint))
    (map-get? campaigns campaign-id)
)

(define-read-only (get-donor-participation (campaign-id uint) (donor principal))
    (map-get? campaign-participations {campaign-id: campaign-id, donor: donor})
)

(define-read-only (get-campaign-progress (campaign-id uint))
    (match (map-get? campaigns campaign-id)
        campaign (ok {
            collected: (get units-collected campaign),
            goal: (get goal-units campaign),
            percentage: (/ (* (get units-collected campaign) u100) (get goal-units campaign))
        })
        err-campaign-not-found
    )
)
