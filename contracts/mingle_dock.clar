;; MingleDock - Decentralized Event Management

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-state (err u103))
(define-constant err-unauthorized (err u104))

;; Data structures
(define-map events 
    { event-id: uint }
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        industry: (string-ascii 50),
        date: uint,
        max-capacity: uint,
        deposit-amount: uint,
        status: (string-ascii 20)
    }
)

(define-map rsvps
    { event-id: uint, attendee: principal }
    {
        status: (string-ascii 20),
        deposit-paid: uint,
        checked-in: bool
    }
)

;; Data variables
(define-data-var next-event-id uint u1)

;; Private functions
(define-private (is-event-creator (event-id uint) (user principal))
    (let ((event (unwrap! (map-get? events {event-id: event-id}) false)))
        (is-eq (get creator event) user)
    )
)

;; Public functions
(define-public (create-event
        (title (string-ascii 100))
        (description (string-ascii 500))
        (industry (string-ascii 50))
        (date uint)
        (max-capacity uint)
        (deposit-amount uint)
    )
    (let ((event-id (var-get next-event-id)))
        (map-insert events
            {event-id: event-id}
            {
                creator: tx-sender,
                title: title,
                description: description,
                industry: industry,
                date: date,
                max-capacity: max-capacity,
                deposit-amount: deposit-amount,
                status: "active"
            }
        )
        (var-set next-event-id (+ event-id u1))
        (ok event-id)
    )
)

(define-public (rsvp (event-id uint))
    (let (
        (event (unwrap! (map-get? events {event-id: event-id}) err-not-found))
        (deposit (get deposit-amount event))
    )
        (asserts! (is-eq (get status event) "active") err-invalid-state)
        (try! (stx-transfer? deposit tx-sender (as-contract tx-sender)))
        (map-insert rsvps
            {event-id: event-id, attendee: tx-sender}
            {status: "confirmed", deposit-paid: deposit, checked-in: false}
        )
        (ok true)
    )
)

(define-public (check-in-attendee (event-id uint) (attendee principal))
    (let ((event (unwrap! (map-get? events {event-id: event-id}) err-not-found)))
        (asserts! (or (is-eq tx-sender (get creator event)) (is-eq tx-sender contract-owner)) err-unauthorized)
        (map-set rsvps
            {event-id: event-id, attendee: attendee}
            {
                status: "attended",
                deposit-paid: (get deposit-paid (unwrap! (map-get? rsvps {event-id: event-id, attendee: attendee}) err-not-found)),
                checked-in: true
            }
        )
        (ok true)
    )
)

(define-public (cancel-event (event-id uint))
    (let ((event (unwrap! (map-get? events {event-id: event-id}) err-not-found)))
        (asserts! (is-event-creator event-id tx-sender) err-unauthorized)
        (map-set events
            {event-id: event-id}
            (merge event {status: "cancelled"})
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-event (event-id uint))
    (ok (map-get? events {event-id: event-id}))
)

(define-read-only (get-rsvp-status (event-id uint) (attendee principal))
    (ok (map-get? rsvps {event-id: event-id, attendee: attendee}))
)