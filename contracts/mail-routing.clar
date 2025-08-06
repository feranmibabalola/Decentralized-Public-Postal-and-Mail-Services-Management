;; Mail Routing and Sorting Optimization Contract
;; Manages efficient mail delivery routes and processing centers

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ROUTE-EXISTS (err u104))

;; Data Variables
(define-data-var next-route-id uint u1)
(define-data-var total-processing-centers uint u0)

;; Data Maps
(define-map routes
  { route-id: uint }
  {
    origin: (string-ascii 50),
    destination: (string-ascii 50),
    distance: uint,
    estimated-time: uint,
    capacity: uint,
    current-load: uint,
    cost-per-item: uint,
    is-active: bool,
    created-by: principal,
    created-at: uint
  }
)

(define-map processing-centers
  { center-id: (string-ascii 20) }
  {
    name: (string-ascii 100),
    location: (string-ascii 50),
    capacity: uint,
    current-load: uint,
    operating-hours: (string-ascii 20),
    manager: principal,
    is-operational: bool
  }
)

(define-map route-assignments
  { mail-id: uint }
  {
    route-id: uint,
    assigned-at: uint,
    estimated-delivery: uint,
    priority-level: uint
  }
)

(define-map authorized-operators
  { operator: principal }
  { is-authorized: bool }
)

;; Authorization Functions
(define-private (is-authorized (user principal))
  (or
    (is-eq user CONTRACT-OWNER)
    (default-to false (get is-authorized (map-get? authorized-operators { operator: user })))
  )
)

;; Route Management Functions
(define-public (create-route (origin (string-ascii 50)) (destination (string-ascii 50)) (distance uint) (estimated-time uint) (capacity uint) (cost-per-item uint))
  (let ((route-id (var-get next-route-id)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> distance u0) ERR-INVALID-INPUT)
    (asserts! (> estimated-time u0) ERR-INVALID-INPUT)
    (asserts! (> capacity u0) ERR-INVALID-INPUT)

    (map-set routes
      { route-id: route-id }
      {
        origin: origin,
        destination: destination,
        distance: distance,
        estimated-time: estimated-time,
        capacity: capacity,
        current-load: u0,
        cost-per-item: cost-per-item,
        is-active: true,
        created-by: tx-sender,
        created-at: block-height
      }
    )

    (var-set next-route-id (+ route-id u1))
    (ok route-id)
  )
)

(define-public (update-route-load (route-id uint) (new-load uint))
  (let ((route-data (unwrap! (map-get? routes { route-id: route-id }) ERR-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-load (get capacity route-data)) ERR-INVALID-INPUT)

    (map-set routes
      { route-id: route-id }
      (merge route-data { current-load: new-load })
    )
    (ok true)
  )
)

(define-public (optimize-route (route-id uint) (new-estimated-time uint))
  (let ((route-data (unwrap! (map-get? routes { route-id: route-id }) ERR-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> new-estimated-time u0) ERR-INVALID-INPUT)

    (map-set routes
      { route-id: route-id }
      (merge route-data { estimated-time: new-estimated-time })
    )
    (ok true)
  )
)

;; Processing Center Management
(define-public (register-processing-center (center-id (string-ascii 20)) (name (string-ascii 100)) (location (string-ascii 50)) (capacity uint) (operating-hours (string-ascii 20)))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> capacity u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? processing-centers { center-id: center-id })) ERR-ROUTE-EXISTS)

    (map-set processing-centers
      { center-id: center-id }
      {
        name: name,
        location: location,
        capacity: capacity,
        current-load: u0,
        operating-hours: operating-hours,
        manager: tx-sender,
        is-operational: true
      }
    )

    (var-set total-processing-centers (+ (var-get total-processing-centers) u1))
    (ok true)
  )
)

(define-public (update-center-load (center-id (string-ascii 20)) (new-load uint))
  (let ((center-data (unwrap! (map-get? processing-centers { center-id: center-id }) ERR-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-load (get capacity center-data)) ERR-INVALID-INPUT)

    (map-set processing-centers
      { center-id: center-id }
      (merge center-data { current-load: new-load })
    )
    (ok true)
  )
)

;; Mail Assignment Functions
(define-public (assign-mail-to-route (mail-id uint) (route-id uint) (priority-level uint))
  (let ((route-data (unwrap! (map-get? routes { route-id: route-id }) ERR-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active route-data) ERR-INVALID-INPUT)
    (asserts! (< (get current-load route-data) (get capacity route-data)) ERR-INVALID-INPUT)
    (asserts! (<= priority-level u5) ERR-INVALID-INPUT)

    (map-set route-assignments
      { mail-id: mail-id }
      {
        route-id: route-id,
        assigned-at: block-height,
        estimated-delivery: (+ block-height (get estimated-time route-data)),
        priority-level: priority-level
      }
    )

    ;; Update route load
    (map-set routes
      { route-id: route-id }
      (merge route-data { current-load: (+ (get current-load route-data) u1) })
    )

    (ok true)
  )
)

;; Authorization Management
(define-public (authorize-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-operators { operator: operator } { is-authorized: true })
    (ok true)
  )
)

(define-public (revoke-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-operators { operator: operator } { is-authorized: false })
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-route (route-id uint))
  (map-get? routes { route-id: route-id })
)

(define-read-only (get-processing-center (center-id (string-ascii 20)))
  (map-get? processing-centers { center-id: center-id })
)

(define-read-only (get-mail-assignment (mail-id uint))
  (map-get? route-assignments { mail-id: mail-id })
)

(define-read-only (get-route-capacity-utilization (route-id uint))
  (match (map-get? routes { route-id: route-id })
    route-data (ok (/ (* (get current-load route-data) u100) (get capacity route-data)))
    ERR-NOT-FOUND
  )
)

(define-read-only (get-total-routes)
  (- (var-get next-route-id) u1)
)

(define-read-only (get-total-processing-centers)
  (var-get total-processing-centers)
)
