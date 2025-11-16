(define-constant err-slot-not-found (err u300))
(define-constant err-slot-taken (err u301))
(define-constant err-invalid-time (err u302))
(define-constant err-appointment-not-found (err u303))
(define-constant err-too-late-to-cancel (err u304))
(define-constant err-not-authorized (err u305))
(define-constant err-invalid-capacity (err u306))

(define-data-var appointment-counter uint u0)
(define-data-var cancellation-window uint u720)

(define-map time-slots {hospital: principal, date: uint, hour: uint} {
    capacity: uint,
    booked: uint,
    created-at: uint,
    active: bool
})

(define-map appointments uint {
    donor: principal,
    hospital: principal,
    scheduled-date: uint,
    scheduled-hour: uint,
    blood-type: (string-ascii 3),
    booked-at: uint,
    status: (string-ascii 10),
    reminder-sent: bool
})

(define-map hospital-schedules {hospital: principal, date: uint} {
    total-slots: uint,
    available-slots: uint,
    efficiency-rating: uint
})

(define-public (create-time-slot (date uint) (hour uint) (capacity uint))
    (let ((hospital tx-sender))
        (asserts! (> capacity u0) err-invalid-capacity)
        (asserts! (> date stacks-block-height) err-invalid-time)
        (ok (map-set time-slots {hospital: hospital, date: date, hour: hour} {
            capacity: capacity,
            booked: u0,
            created-at: stacks-block-height,
            active: true
        }))
    )
)

(define-public (book-appointment (hospital principal) (date uint) (hour uint) (blood-type (string-ascii 3)))
    (let (
        (slot-key {hospital: hospital, date: date, hour: hour})
        (slot-data (unwrap! (map-get? time-slots slot-key) err-slot-not-found))
        (appointment-id (+ (var-get appointment-counter) u1))
    )
        (asserts! (get active slot-data) err-slot-not-found)
        (asserts! (< (get booked slot-data) (get capacity slot-data)) err-slot-taken)
        (asserts! (> date stacks-block-height) err-invalid-time)
        
        (map-set appointments appointment-id {
            donor: tx-sender,
            hospital: hospital,
            scheduled-date: date,
            scheduled-hour: hour,
            blood-type: blood-type,
            booked-at: stacks-block-height,
            status: "scheduled",
            reminder-sent: false
        })
        
        (map-set time-slots slot-key (merge slot-data {
            booked: (+ (get booked slot-data) u1)
        }))
        
        (var-set appointment-counter appointment-id)
        (ok appointment-id)
    )
)

(define-public (cancel-appointment (appointment-id uint))
    (let ((appointment-data (unwrap! (map-get? appointments appointment-id) err-appointment-not-found)))
        (asserts! (is-eq tx-sender (get donor appointment-data)) err-not-authorized)
        (asserts! (> (get scheduled-date appointment-data) (+ stacks-block-height (var-get cancellation-window))) err-too-late-to-cancel)
        (asserts! (is-eq (get status appointment-data) "scheduled") err-appointment-not-found)
        
        (let ((slot-key {hospital: (get hospital appointment-data), date: (get scheduled-date appointment-data), hour: (get scheduled-hour appointment-data)}))
            (match (map-get? time-slots slot-key)
                slot-data (map-set time-slots slot-key (merge slot-data {booked: (- (get booked slot-data) u1)}))
                false
            )
        )
        
        (ok (map-set appointments appointment-id (merge appointment-data {status: "cancelled"})))
    )
)

(define-read-only (get-available-slots (hospital principal) (date uint))
    (let ((schedule-key {hospital: hospital, date: date}))
        (map-get? hospital-schedules schedule-key)
    )
)

(define-read-only (get-appointment-info (appointment-id uint))
    (map-get? appointments appointment-id)
)

(define-read-only (get-slot-info (hospital principal) (date uint) (hour uint))
    (map-get? time-slots {hospital: hospital, date: date, hour: hour})
)
