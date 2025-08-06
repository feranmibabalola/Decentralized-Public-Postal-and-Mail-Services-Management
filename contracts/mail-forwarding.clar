;; Mail Forwarding Service Coordination Contract
;; Handles address changes and mail redirection services

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-FORWARDING-EXPIRED (err u105))

;; Forwarding Type Constants
(define-constant TYPE-TEMPORARY u1)
(define-constant TYPE-PERMANENT u2)
(define-constant TYPE-BUSINESS u3)

;; Data Variables
(define-data-var next-forwarding-id uint u1)
(define-data-var total-forwarding-orders uint u0)
(define-data-var total-mail-forwarded uint u0)

;; Pricing (in microSTX)
(define-data-var temporary-forwarding-fee uint u25000000)  ;; 25 STX per month
(define-data-var permanent-forwarding-fee uint u50000000) ;; 50 STX per month
(define-data-var business-forwarding-fee uint u100000000) ;; 100 STX per month
(define-data-var per-item-fee uint u1000000)              ;; 1 STX per item

;; Data Maps
(define-map forwarding-orders
  { forwarding-id: uint }
  {
    customer: principal,
    customer-name: (string-ascii 100),
    old-address: (string-ascii 200),
    new-address: (string-ascii 200),
    forwarding-type: uint,
    start-date: uint,
    end-date: uint,
    monthly-fee: uint,
    per-item-fee: uint,
    is-active: bool,
    auto-renew: bool,
    special-instructions: (optional (string-ascii 200)),
    created-at: uint
  }
)

(define-map forwarded-mail
  { forwarding-id: uint, mail-id: uint }
  {
    original-address: (string-ascii 200),
    forwarded-to: (string-ascii 200),
    mail-type: (string-ascii 50),
    forwarded-date: uint,
    tracking-number: (optional uint),
    forwarding-fee: uint,
    handler: principal
  }
)

(define-map forwarding-mail-count
  { forwarding-id: uint }
  { mail-count: uint }
)

(define-map address-changes
  { customer: principal, change-id: uint }
  {
    old-address: (string-ascii 200),
    new-address: (string-ascii 200),
    effective-date: uint,
    change-reason: (string-ascii 100),
    verification-status: bool,
    verified-by: (optional principal),
    verified-at: (optional uint)
  }
)

(define-map customer-changes
  { customer: principal }
  { change-count: uint }
)

(define-map forwarding-payments
  { forwarding-id: uint, payment-id: uint }
  {
    amount: uint,
    payment-date: uint,
    period-start: uint,
    period-end: uint,
    payment-type: (string-ascii 50)
  }
)

(define-map forwarding-payment-count
  { forwarding-id: uint }
  { payment-count: uint }
)

(define-map authorized-handlers
  { handler: principal }
  { is-authorized: bool }
)

;; Authorization Functions
(define-private (is-authorized (user principal))
  (or
    (is-eq user CONTRACT-OWNER)
    (default-to false (get is-authorized (map-get? authorized-handlers { handler: user })))
  )
)

(define-private (is-valid-forwarding-type (forwarding-type uint))
  (and (>= forwarding-type TYPE-TEMPORARY) (<= forwarding-type TYPE-BUSINESS))
)

(define-private (get-forwarding-fee (forwarding-type uint))
  (if (is-eq forwarding-type TYPE-TEMPORARY)
    (var-get temporary-forwarding-fee)
    (if (is-eq forwarding-type TYPE-PERMANENT)
      (var-get permanent-forwarding-fee)
      (var-get business-forwarding-fee)
    )
  )
)

;; Forwarding Order Management
(define-public (create-forwarding-order (customer-name (string-ascii 100)) (old-address (string-ascii 200)) (new-address (string-ascii 200)) (forwarding-type uint) (duration-months uint) (auto-renew bool) (special-instructions (optional (string-ascii 200))))
  (let ((forwarding-id (var-get next-forwarding-id))
        (monthly-fee (get-forwarding-fee forwarding-type))
        (total-cost (* monthly-fee duration-months))
        (end-date (+ block-height (* duration-months u144)))) ;; Approximate blocks per month

    (asserts! (is-valid-forwarding-type forwarding-type) ERR-INVALID-INPUT)
    (asserts! (> duration-months u0) ERR-INVALID-INPUT)
    (asserts! (<= duration-months u24) ERR-INVALID-INPUT)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR-INSUFFICIENT-FUNDS)

    ;; Transfer payment
    (unwrap! (stx-transfer? total-cost tx-sender (as-contract tx-sender)) (err u999))

    ;; Create forwarding order
    (map-set forwarding-orders
      { forwarding-id: forwarding-id }
      {
        customer: tx-sender,
        customer-name: customer-name,
        old-address: old-address,
        new-address: new-address,
        forwarding-type: forwarding-type,
        start-date: block-height,
        end-date: end-date,
        monthly-fee: monthly-fee,
        per-item-fee: (var-get per-item-fee),
        is-active: true,
        auto-renew: auto-renew,
        special-instructions: special-instructions,
        created-at: block-height
      }
    )

    ;; Initialize counters
    (map-set forwarding-mail-count
      { forwarding-id: forwarding-id }
      { mail-count: u0 }
    )

    (map-set forwarding-payment-count
      { forwarding-id: forwarding-id }
      { payment-count: u0 }
    )

    ;; Record payment
    (unwrap-panic (record-forwarding-payment forwarding-id total-cost "Initial Payment"))

    (var-set next-forwarding-id (+ forwarding-id u1))
    (var-set total-forwarding-orders (+ (var-get total-forwarding-orders) u1))
    (ok forwarding-id)
  )
)

(define-public (extend-forwarding (forwarding-id uint) (additional-months uint))
  (let ((order-data (unwrap! (map-get? forwarding-orders { forwarding-id: forwarding-id }) ERR-NOT-FOUND))
        (extension-cost (* (get monthly-fee order-data) additional-months))
        (new-end-date (+ (get end-date order-data) (* additional-months u144))))

    (asserts! (is-eq tx-sender (get customer order-data)) ERR-NOT-AUTHORIZED)
    (asserts! (> additional-months u0) ERR-INVALID-INPUT)
    (asserts! (<= additional-months u12) ERR-INVALID-INPUT)
    (asserts! (>= (stx-get-balance tx-sender) extension-cost) ERR-INSUFFICIENT-FUNDS)

    ;; Transfer payment
    (unwrap! (stx-transfer? extension-cost tx-sender (as-contract tx-sender)) (err u999))

    ;; Update order
    (map-set forwarding-orders
      { forwarding-id: forwarding-id }
      (merge order-data { end-date: new-end-date })
    )

    ;; Record payment
    (unwrap-panic (record-forwarding-payment forwarding-id extension-cost "Extension Payment"))

    (ok true)
  )
)

(define-public (update-forwarding-address (forwarding-id uint) (new-address (string-ascii 200)))
  (let ((order-data (unwrap! (map-get? forwarding-orders { forwarding-id: forwarding-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get customer order-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active order-data) ERR-FORWARDING-EXPIRED)

    (map-set forwarding-orders
      { forwarding-id: forwarding-id }
      (merge order-data { new-address: new-address })
    )
    (ok true)
  )
)

(define-public (cancel-forwarding (forwarding-id uint))
  (let ((order-data (unwrap! (map-get? forwarding-orders { forwarding-id: forwarding-id }) ERR-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender (get customer order-data)) (is-authorized tx-sender)) ERR-NOT-AUTHORIZED)

    (map-set forwarding-orders
      { forwarding-id: forwarding-id }
      (merge order-data { is-active: false })
    )
    (ok true)
  )
)

;; Mail Forwarding Operations
(define-public (forward-mail (forwarding-id uint) (mail-type (string-ascii 50)) (tracking-number (optional uint)))
  (let ((order-data (unwrap! (map-get? forwarding-orders { forwarding-id: forwarding-id }) ERR-NOT-FOUND))
        (mail-count-data (unwrap! (map-get? forwarding-mail-count { forwarding-id: forwarding-id }) ERR-NOT-FOUND))
        (mail-id (get mail-count mail-count-data))
        (forwarding-fee (get per-item-fee order-data)))

    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active order-data) ERR-FORWARDING-EXPIRED)
    (asserts! (> (get end-date order-data) block-height) ERR-FORWARDING-EXPIRED)

    ;; Record forwarded mail
    (map-set forwarded-mail
      { forwarding-id: forwarding-id, mail-id: mail-id }
      {
        original-address: (get old-address order-data),
        forwarded-to: (get new-address order-data),
        mail-type: mail-type,
        forwarded-date: block-height,
        tracking-number: tracking-number,
        forwarding-fee: forwarding-fee,
        handler: tx-sender
      }
    )

    ;; Update mail count
    (map-set forwarding-mail-count
      { forwarding-id: forwarding-id }
      { mail-count: (+ mail-id u1) }
    )

    (var-set total-mail-forwarded (+ (var-get total-mail-forwarded) u1))
    (ok mail-id)
  )
)

;; Address Change Management
(define-public (register-address-change (old-address (string-ascii 200)) (new-address (string-ascii 200)) (effective-date uint) (change-reason (string-ascii 100)))
  (let ((change-count-data (default-to { change-count: u0 } (map-get? customer-changes { customer: tx-sender })))
        (change-id (get change-count change-count-data)))

    (asserts! (> effective-date block-height) ERR-INVALID-INPUT)

    (map-set address-changes
      { customer: tx-sender, change-id: change-id }
      {
        old-address: old-address,
        new-address: new-address,
        effective-date: effective-date,
        change-reason: change-reason,
        verification-status: false,
        verified-by: none,
        verified-at: none
      }
    )

    (map-set customer-changes
      { customer: tx-sender }
      { change-count: (+ change-id u1) }
    )

    (ok change-id)
  )
)

(define-public (verify-address-change (customer principal) (change-id uint))
  (let ((change-data (unwrap! (map-get? address-changes { customer: customer, change-id: change-id }) ERR-NOT-FOUND)))
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

    (map-set address-changes
      { customer: customer, change-id: change-id }
      (merge change-data {
        verification-status: true,
        verified-by: (some tx-sender),
        verified-at: (some block-height)
      })
    )
    (ok true)
  )
)

(define-private (record-forwarding-payment (forwarding-id uint) (amount uint) (payment-type (string-ascii 50)))
  (let ((payment-count-data (unwrap! (map-get? forwarding-payment-count { forwarding-id: forwarding-id }) ERR-NOT-FOUND))
        (payment-id (get payment-count payment-count-data)))

    (map-set forwarding-payments
      { forwarding-id: forwarding-id, payment-id: payment-id }
      {
        amount: amount,
        payment-date: block-height,
        period-start: block-height,
        period-end: (+ block-height u144),
        payment-type: payment-type
      }
    )

    (map-set forwarding-payment-count
      { forwarding-id: forwarding-id }
      { payment-count: (+ payment-id u1) }
    )

    (ok true)
  )
)

;; Pricing Management
(define-public (update-forwarding-fees (forwarding-type uint) (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-forwarding-type forwarding-type) ERR-INVALID-INPUT)
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)

    (if (is-eq forwarding-type TYPE-TEMPORARY)
      (var-set temporary-forwarding-fee new-fee)
      (if (is-eq forwarding-type TYPE-PERMANENT)
        (var-set permanent-forwarding-fee new-fee)
        (var-set business-forwarding-fee new-fee)
      )
    )
    (ok true)
  )
)

(define-public (update-per-item-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)
    (var-set per-item-fee new-fee)
    (ok true)
  )
)

;; Authorization Management
(define-public (authorize-handler (handler principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-handlers { handler: handler } { is-authorized: true })
    (ok true)
  )
)

(define-public (revoke-handler (handler principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-handlers { handler: handler } { is-authorized: false })
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-forwarding-order (forwarding-id uint))
  (map-get? forwarding-orders { forwarding-id: forwarding-id })
)

(define-read-only (get-forwarded-mail (forwarding-id uint) (mail-id uint))
  (map-get? forwarded-mail { forwarding-id: forwarding-id, mail-id: mail-id })
)

(define-read-only (get-address-change (customer principal) (change-id uint))
  (map-get? address-changes { customer: customer, change-id: change-id })
)

(define-read-only (get-forwarding-payment (forwarding-id uint) (payment-id uint))
  (map-get? forwarding-payments { forwarding-id: forwarding-id, payment-id: payment-id })
)

(define-read-only (is-forwarding-active (forwarding-id uint))
  (match (map-get? forwarding-orders { forwarding-id: forwarding-id })
    order-data (ok (and (get is-active order-data) (> (get end-date order-data) block-height)))
    ERR-NOT-FOUND
  )
)

(define-read-only (get-forwarding-stats)
  {
    total-orders: (var-get total-forwarding-orders),
    total-mail-forwarded: (var-get total-mail-forwarded),
    next-forwarding-id: (var-get next-forwarding-id)
  }
)

(define-read-only (get-forwarding-fees)
  {
    temporary: (var-get temporary-forwarding-fee),
    permanent: (var-get permanent-forwarding-fee),
    business: (var-get business-forwarding-fee),
    per-item: (var-get per-item-fee)
  }
)
