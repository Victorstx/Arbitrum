;; Arbitrum - Decentralized Legal Agreement Platform
;; A smart contract for managing legal agreements with dispute resolution, multi-asset support, and template library

;; Define the SIP-10 trait for token transfers
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-AGREEMENT-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-SIGNED (err u102))
(define-constant ERR-NOT-PARTY (err u103))
(define-constant ERR-ALREADY-DISPUTED (err u104))
(define-constant ERR-INVALID-STATUS (err u105))
(define-constant ERR-INSUFFICIENT-STAKE (err u106))
(define-constant ERR-INVALID-INPUT (err u107))
(define-constant ERR-INVALID-PRINCIPAL (err u108))
(define-constant ERR-INVALID-HASH (err u109))
(define-constant ERR-UNSUPPORTED-ASSET (err u110))
(define-constant ERR-TRANSFER-FAILED (err u111))
(define-constant ERR-ASSET-MISMATCH (err u112))
(define-constant ERR-TEMPLATE-NOT-FOUND (err u113))
(define-constant ERR-TEMPLATE-EXISTS (err u114))
(define-constant ERR-INVALID-TEMPLATE-PARAM (err u115))
(define-constant ERR-REQUIRED-PARAM-MISSING (err u116))

;; Asset Types
(define-constant ASSET-STX u0)
(define-constant ASSET-SIP10 u1)

;; Data Variables
(define-data-var next-agreement-id uint u1)
(define-data-var platform-fee uint u100) ;; 1% fee in basis points
(define-data-var next-template-id uint u1)

;; Agreement Status
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-DISPUTED u3)
(define-constant STATUS-RESOLVED u4)

;; Template parameter structure
(define-map template-parameters
  {template-id: (string-ascii 32), param-key: (string-ascii 32)}
  {
    param-value: (string-ascii 100),
    required: bool
  })

;; Templates structure
(define-map templates
  (string-ascii 32)
  {
    name: (string-ascii 100),
    category: (string-ascii 32),
    ipfs-hash: (string-ascii 64),
    creator: principal,
    enabled: bool,
    created-at: uint,
    usage-count: uint
  })

;; Asset info structure for SIP-10 tokens
(define-map supported-assets
  principal
  {
    name: (string-ascii 32),
    enabled: bool
  })

;; Maps
(define-map agreements
  uint
  {
    party-a: principal,
    party-b: principal,
    title: (string-ascii 100),
    ipfs-hash: (string-ascii 64),
    template-id: (optional (string-ascii 32)),
    stake-amount: uint,
    asset-type: uint,
    asset-contract: (optional principal),
    status: uint,
    created-at: uint,
    signatures: uint,
    dispute-reason: (optional (string-ascii 200))
  })

(define-map signatures
  {agreement-id: uint, signer: principal}
  {signed-at: uint, signature-hash: (string-ascii 64)})

(define-map disputes
  uint
  {
    initiator: principal,
    reason: (string-ascii 200),
    created-at: uint,
    votes-for-a: uint,
    votes-for-b: uint,
    resolved: bool,
    winner: (optional principal)
  })

(define-map arbitrators principal bool)

;; Agreement custom parameters for template-based agreements
(define-map agreement-parameters
  {agreement-id: uint, param-key: (string-ascii 32)}
  (string-ascii 100))

;; Read-only functions
(define-read-only (get-agreement (agreement-id uint))
  (map-get? agreements agreement-id))

(define-read-only (get-signature (agreement-id uint) (signer principal))
  (map-get? signatures {agreement-id: agreement-id, signer: signer}))

(define-read-only (get-dispute (agreement-id uint))
  (map-get? disputes agreement-id))

(define-read-only (is-arbitrator (address principal))
  (default-to false (map-get? arbitrators address)))

(define-read-only (get-next-agreement-id)
  (var-get next-agreement-id))

(define-read-only (get-platform-fee)
  (var-get platform-fee))

(define-read-only (is-supported-asset (asset-contract principal))
  ;; Currently only STX is natively supported
  false)

(define-read-only (get-supported-asset (asset-contract principal))
  ;; Returns none as SIP-10 support is not yet implemented
  none)

(define-read-only (get-template (template-id (string-ascii 32)))
  (map-get? templates template-id))

(define-read-only (get-template-parameter (template-id (string-ascii 32)) (param-key (string-ascii 32)))
  (map-get? template-parameters {template-id: template-id, param-key: param-key}))

(define-read-only (get-agreement-parameter (agreement-id uint) (param-key (string-ascii 32)))
  (map-get? agreement-parameters {agreement-id: agreement-id, param-key: param-key}))

(define-read-only (get-next-template-id)
  (var-get next-template-id))

;; Private functions
(define-private (is-party (agreement-id uint) (user principal))
  (match (map-get? agreements agreement-id)
    agreement (or (is-eq (get party-a agreement) user)
                  (is-eq (get party-b agreement) user))
    false))

(define-private (both-parties-signed (agreement-id uint))
  (match (map-get? agreements agreement-id)
    agreement (is-eq (get signatures agreement) u2)
    false))

(define-private (is-valid-principal (address principal))
  (not (is-eq address tx-sender)))

(define-private (is-valid-string (input (string-ascii 200)))
  (and (> (len input) u0) (<= (len input) u200)))

(define-private (is-valid-hash (hash (string-ascii 64)))
  (and (> (len hash) u10) (<= (len hash) u64)))

(define-private (is-valid-title (title (string-ascii 100)))
  (and (> (len title) u0) (<= (len title) u100)))

(define-private (is-valid-asset-name (name (string-ascii 32)))
  (and (> (len name) u0) (<= (len name) u32)))

(define-private (is-valid-template-id (template-id (string-ascii 32)))
  (and (> (len template-id) u0) (<= (len template-id) u32)))

(define-private (is-valid-param-key (param-key (string-ascii 32)))
  (and (> (len param-key) u0) (<= (len param-key) u32)))

(define-private (is-valid-param-value (param-value (string-ascii 100)))
  (and (> (len param-value) u0) (<= (len param-value) u100)))

(define-private (is-valid-category (category (string-ascii 32)))
  (and (> (len category) u0) (<= (len category) u32)))

;; Asset transfer functions
(define-private (transfer-stx (amount uint) (sender principal) (recipient principal))
  (stx-transfer? amount sender recipient))

;; For this implementation, we'll focus on STX transfers
;; SIP-10 token support can be added through specific contract integrations
(define-private (transfer-asset (asset-type uint) (asset-contract (optional principal)) (amount uint) (sender principal) (recipient principal))
  (if (is-eq asset-type ASSET-STX)
    (transfer-stx amount sender recipient)
    ;; For now, only STX is supported in the core contract
    ;; SIP-10 tokens require specific contract integration
    ERR-UNSUPPORTED-ASSET))

;; Template management functions

;; Add a new template (admin only)
(define-public (add-template 
  (template-id (string-ascii 32))
  (name (string-ascii 100))
  (category (string-ascii 32))
  (ipfs-hash (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-valid-template-id template-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-title name) ERR-INVALID-INPUT)
    (asserts! (is-valid-category category) ERR-INVALID-INPUT)
    (asserts! (is-valid-hash ipfs-hash) ERR-INVALID-HASH)
    (asserts! (is-none (map-get? templates template-id)) ERR-TEMPLATE-EXISTS)
    
    (map-set templates template-id {
      name: name,
      category: category,
      ipfs-hash: ipfs-hash,
      creator: tx-sender,
      enabled: true,
      created-at: stacks-block-height,
      usage-count: u0
    })
    (ok true)))

;; Update existing template (admin only)
(define-public (update-template
  (template-id (string-ascii 32))
  (name (string-ascii 100))
  (ipfs-hash (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-valid-template-id template-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-title name) ERR-INVALID-INPUT)
    (asserts! (is-valid-hash ipfs-hash) ERR-INVALID-HASH)
    
    (match (map-get? templates template-id)
      template (let ((validated-id template-id))
        (map-set templates validated-id {
          name: name,
          category: (get category template),
          ipfs-hash: ipfs-hash,
          creator: (get creator template),
          enabled: (get enabled template),
          created-at: (get created-at template),
          usage-count: (get usage-count template)
        })
        (ok true))
      ERR-TEMPLATE-NOT-FOUND)))

;; Add template parameter definition (admin only)
(define-public (add-template-parameter
  (template-id (string-ascii 32))
  (param-key (string-ascii 32))
  (default-value (string-ascii 100))
  (required bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-some (map-get? templates template-id)) ERR-TEMPLATE-NOT-FOUND)
    (asserts! (is-valid-param-key param-key) ERR-INVALID-INPUT)
    (asserts! (is-valid-param-value default-value) ERR-INVALID-INPUT)
    
    (map-set template-parameters 
      {template-id: template-id, param-key: param-key}
      {param-value: default-value, required: required})
    (ok true)))

;; Enable/disable template (admin only)
(define-public (toggle-template (template-id (string-ascii 32)) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-valid-template-id template-id) ERR-INVALID-INPUT)
    
    (match (map-get? templates template-id)
      template (let ((validated-id template-id))
        (map-set templates validated-id {
          name: (get name template),
          category: (get category template),
          ipfs-hash: (get ipfs-hash template),
          creator: (get creator template),
          enabled: enabled,
          created-at: (get created-at template),
          usage-count: (get usage-count template)
        })
        (ok true))
      ERR-TEMPLATE-NOT-FOUND)))

;; Public functions

;; Create a new legal agreement with STX
(define-public (create-agreement 
  (party-b principal)
  (title (string-ascii 100))
  (ipfs-hash (string-ascii 64))
  (stake-amount uint))
  (create-agreement-with-asset party-b title ipfs-hash stake-amount ASSET-STX none))

;; Create a new legal agreement with specified asset
(define-public (create-agreement-with-asset
  (party-b principal)
  (title (string-ascii 100))
  (ipfs-hash (string-ascii 64))
  (stake-amount uint)
  (asset-type uint)
  (asset-contract (optional principal)))
  (let ((agreement-id (var-get next-agreement-id)))
    (asserts! (> stake-amount u0) ERR-INSUFFICIENT-STAKE)
    (asserts! (not (is-eq party-b tx-sender)) ERR-INVALID-PRINCIPAL)
    (asserts! (is-valid-title title) ERR-INVALID-INPUT)
    (asserts! (is-valid-hash ipfs-hash) ERR-INVALID-HASH)
    
    ;; For initial implementation, only STX is supported
    (asserts! (is-eq asset-type ASSET-STX) ERR-UNSUPPORTED-ASSET)
    (asserts! (is-none asset-contract) ERR-INVALID-INPUT)
    
    ;; Transfer stake to contract
    (try! (transfer-asset asset-type asset-contract stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set agreements agreement-id {
      party-a: tx-sender,
      party-b: party-b,
      title: title,
      ipfs-hash: ipfs-hash,
      template-id: none,
      stake-amount: stake-amount,
      asset-type: asset-type,
      asset-contract: asset-contract,
      status: STATUS-PENDING,
      created-at: stacks-block-height,
      signatures: u0,
      dispute-reason: none
    })
    (var-set next-agreement-id (+ agreement-id u1))
    (ok agreement-id)))

;; Create agreement from template
(define-public (create-agreement-from-template
  (party-b principal)
  (template-id (string-ascii 32))
  (stake-amount uint)
  (custom-params (list 20 {key: (string-ascii 32), value: (string-ascii 100)})))
  (let (
    (template (unwrap! (map-get? templates template-id) ERR-TEMPLATE-NOT-FOUND))
    (agreement-id (var-get next-agreement-id)))
    
    (asserts! (> stake-amount u0) ERR-INSUFFICIENT-STAKE)
    (asserts! (not (is-eq party-b tx-sender)) ERR-INVALID-PRINCIPAL)
    (asserts! (get enabled template) ERR-INVALID-STATUS)
    
    ;; Transfer stake to contract
    (try! (transfer-asset ASSET-STX none stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Store custom parameters
    (fold store-single-parameter custom-params agreement-id)
    
    ;; Update template usage count
    (match (map-get? templates template-id)
      existing-template (map-set templates template-id {
        name: (get name existing-template),
        category: (get category existing-template),
        ipfs-hash: (get ipfs-hash existing-template),
        creator: (get creator existing-template),
        enabled: (get enabled existing-template),
        created-at: (get created-at existing-template),
        usage-count: (+ (get usage-count existing-template) u1)
      })
      false)
    
    (map-set agreements agreement-id {
      party-a: tx-sender,
      party-b: party-b,
      title: (get name template),
      ipfs-hash: (get ipfs-hash template),
      template-id: (some template-id),
      stake-amount: stake-amount,
      asset-type: ASSET-STX,
      asset-contract: none,
      status: STATUS-PENDING,
      created-at: stacks-block-height,
      signatures: u0,
      dispute-reason: none
    })
    (var-set next-agreement-id (+ agreement-id u1))
    (ok agreement-id)))

;; Helper function to store agreement parameters
(define-private (store-single-parameter 
  (param {key: (string-ascii 32), value: (string-ascii 100)})
  (agreement-id uint))
  (begin
    (map-set agreement-parameters 
      {agreement-id: agreement-id, param-key: (get key param)}
      (get value param))
    agreement-id))

;; Sign an agreement
(define-public (sign-agreement (agreement-id uint) (signature-hash (string-ascii 64)))
  (let ((agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND)))
    (asserts! (is-party agreement-id tx-sender) ERR-NOT-PARTY)
    (asserts! (is-valid-hash signature-hash) ERR-INVALID-HASH)
    (asserts! (is-none (map-get? signatures {agreement-id: agreement-id, signer: tx-sender})) 
              ERR-ALREADY-SIGNED)
    
    ;; If party-b is signing, they need to match the stake
    (if (is-eq tx-sender (get party-b agreement))
      (try! (transfer-asset 
        (get asset-type agreement) 
        (get asset-contract agreement) 
        (get stake-amount agreement) 
        tx-sender 
        (as-contract tx-sender)))
      true)
    
    (map-set signatures 
      {agreement-id: agreement-id, signer: tx-sender}
      {signed-at: stacks-block-height, signature-hash: signature-hash})
    
    (let ((new-signature-count (+ (get signatures agreement) u1)))
      (map-set agreements agreement-id 
        (merge agreement {
          signatures: new-signature-count,
          status: (if (is-eq new-signature-count u2) STATUS-ACTIVE STATUS-PENDING)
        }))
      (ok true))))

;; Complete an agreement (both parties must call this)
(define-public (complete-agreement (agreement-id uint))
  (let ((agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND)))
    (asserts! (is-party agreement-id tx-sender) ERR-NOT-PARTY)
    (asserts! (is-eq (get status agreement) STATUS-ACTIVE) ERR-INVALID-STATUS)
    (asserts! (both-parties-signed agreement-id) ERR-INVALID-STATUS)
    
    (map-set agreements agreement-id 
      (merge agreement {status: STATUS-COMPLETED}))
    
    ;; Return stakes to both parties
    (try! (as-contract (transfer-asset 
      (get asset-type agreement) 
      (get asset-contract agreement)
      (get stake-amount agreement) 
      tx-sender 
      (get party-a agreement))))
    (try! (as-contract (transfer-asset 
      (get asset-type agreement) 
      (get asset-contract agreement)
      (get stake-amount agreement) 
      tx-sender 
      (get party-b agreement))))
    (ok true)))

;; Initiate a dispute
(define-public (create-dispute (agreement-id uint) (reason (string-ascii 200)))
  (let ((agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND)))
    (asserts! (is-party agreement-id tx-sender) ERR-NOT-PARTY)
    (asserts! (is-eq (get status agreement) STATUS-ACTIVE) ERR-INVALID-STATUS)
    (asserts! (is-valid-string reason) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? disputes agreement-id)) ERR-ALREADY-DISPUTED)
    
    (map-set disputes agreement-id {
      initiator: tx-sender,
      reason: reason,
      created-at: stacks-block-height,
      votes-for-a: u0,
      votes-for-b: u0,
      resolved: false,
      winner: none
    })
    (map-set agreements agreement-id 
      (merge agreement {
        status: STATUS-DISPUTED,
        dispute-reason: (some reason)
      }))
    (ok true)))

;; Vote on a dispute (arbitrators only)
(define-public (vote-on-dispute (agreement-id uint) (vote-for-party-a bool))
  (let (
    (dispute (unwrap! (map-get? disputes agreement-id) ERR-AGREEMENT-NOT-FOUND))
    (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND)))
    (asserts! (is-arbitrator tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (get resolved dispute)) ERR-INVALID-STATUS)
    
    (let ((new-votes-a (if vote-for-party-a (+ (get votes-for-a dispute) u1) (get votes-for-a dispute)))
          (new-votes-b (if vote-for-party-a (get votes-for-b dispute) (+ (get votes-for-b dispute) u1))))
      (map-set disputes agreement-id 
        (merge dispute {
          votes-for-a: new-votes-a,
          votes-for-b: new-votes-b
        }))
      
      ;; Check if dispute is resolved (need at least 3 votes and clear majority)
      (if (and (>= (+ new-votes-a new-votes-b) u3)
               (or (> new-votes-a (* new-votes-b u2))
                   (> new-votes-b (* new-votes-a u2))))
        (let ((winner (if (> new-votes-a new-votes-b) (get party-a agreement) (get party-b agreement))))
          (map-set disputes agreement-id 
            (merge dispute {
              votes-for-a: new-votes-a,
              votes-for-b: new-votes-b,
              resolved: true,
              winner: (some winner)
            }))
          (map-set agreements agreement-id 
            (merge agreement {status: STATUS-RESOLVED}))
          
          ;; Transfer both stakes to winner
          (try! (as-contract (transfer-asset 
            (get asset-type agreement) 
            (get asset-contract agreement)
            (* (get stake-amount agreement) u2) 
            tx-sender 
            winner)))
          (ok true))
        (ok true)))))

;; Asset management functions (placeholder for future SIP-10 support)
(define-public (add-supported-asset (asset-contract principal) (name (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq asset-contract tx-sender)) ERR-INVALID-PRINCIPAL)
    (asserts! (is-valid-asset-name name) ERR-INVALID-INPUT)
    ;; Currently only STX is supported, SIP-10 support coming in future updates
    ERR-UNSUPPORTED-ASSET))

(define-public (disable-asset (asset-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    ;; SIP-10 asset management will be implemented in future versions
    ERR-UNSUPPORTED-ASSET))

(define-public (enable-asset (asset-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    ;; SIP-10 asset management will be implemented in future versions
    ERR-UNSUPPORTED-ASSET))

;; Admin functions
(define-public (add-arbitrator (address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address tx-sender)) ERR-INVALID-PRINCIPAL)
    (map-set arbitrators address true)
    (ok true)))

(define-public (remove-arbitrator (address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq address CONTRACT-OWNER)) ERR-INVALID-PRINCIPAL)
    (map-delete arbitrators address)
    (ok true)))

(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-INPUT) ;; Max 10% fee
    (var-set platform-fee new-fee)
    (ok true)))

;; Initialize default templates
(define-private (init-default-templates)
  (begin
    ;; Initialize NDA template
    (map-set templates "TEMPLATE-NDA" {
      name: "Non-Disclosure Agreement",
      category: "confidentiality",
      ipfs-hash: "QmNDATemplateHash123456789012345678901234567890123456789012",
      creator: CONTRACT-OWNER,
      enabled: true,
      created-at: stacks-block-height,
      usage-count: u0
    })
    
    ;; Initialize Employment template  
    (map-set templates "TEMPLATE-EMPLOYMENT" {
      name: "Employment Contract",
      category: "employment",
      ipfs-hash: "QmEMPTemplateHash123456789012345678901234567890123456789012",
      creator: CONTRACT-OWNER,
      enabled: true,
      created-at: stacks-block-height,
      usage-count: u0
    })
    
    ;; Initialize Partnership template
    (map-set templates "TEMPLATE-PARTNERSHIP" {
      name: "Partnership Agreement", 
      category: "business",
      ipfs-hash: "QmPARTemplateHash123456789012345678901234567890123456789012",
      creator: CONTRACT-OWNER,
      enabled: true,
      created-at: stacks-block-height,
      usage-count: u0
    })
    
    ;; Initialize Service template
    (map-set templates "TEMPLATE-SERVICE" {
      name: "Service Agreement",
      category: "service",
      ipfs-hash: "QmSRVTemplateHash123456789012345678901234567890123456789012",
      creator: CONTRACT-OWNER,
      enabled: true,
      created-at: stacks-block-height,
      usage-count: u0
    })
    
    ;; Initialize Vendor template
    (map-set templates "TEMPLATE-VENDOR" {
      name: "Vendor Contract",
      category: "vendor",
      ipfs-hash: "QmVNDTemplateHash123456789012345678901234567890123456789012",
      creator: CONTRACT-OWNER,
      enabled: true,
      created-at: stacks-block-height,
      usage-count: u0
    })
    
    ;; Add default parameters for NDA template
    (map-set template-parameters 
      {template-id: "TEMPLATE-NDA", param-key: "confidentiality-period"}
      {param-value: "24", required: true})
    (map-set template-parameters 
      {template-id: "TEMPLATE-NDA", param-key: "mutual-disclosure"}
      {param-value: "true", required: false})
    
    ;; Add default parameters for Employment template
    (map-set template-parameters 
      {template-id: "TEMPLATE-EMPLOYMENT", param-key: "job-title"}
      {param-value: "Employee", required: true})
    (map-set template-parameters 
      {template-id: "TEMPLATE-EMPLOYMENT", param-key: "salary-amount"}
      {param-value: "50000", required: true})
    (map-set template-parameters 
      {template-id: "TEMPLATE-EMPLOYMENT", param-key: "start-date"}
      {param-value: "2025-01-01", required: true})
    
    ;; Add default parameters for Partnership template
    (map-set template-parameters 
      {template-id: "TEMPLATE-PARTNERSHIP", param-key: "partnership-percentage"}
      {param-value: "50", required: true})
    (map-set template-parameters 
      {template-id: "TEMPLATE-PARTNERSHIP", param-key: "capital-contribution"}
      {param-value: "10000", required: false})
    
    ;; Add default parameters for Service template
    (map-set template-parameters 
      {template-id: "TEMPLATE-SERVICE", param-key: "service-scope"}
      {param-value: "Consulting Services", required: true})
    (map-set template-parameters 
      {template-id: "TEMPLATE-SERVICE", param-key: "project-timeline"}
      {param-value: "30", required: true})
    
    ;; Add default parameters for Vendor template
    (map-set template-parameters 
      {template-id: "TEMPLATE-VENDOR", param-key: "product-description"}
      {param-value: "Goods and Services", required: true})
    (map-set template-parameters 
      {template-id: "TEMPLATE-VENDOR", param-key: "delivery-timeline"}
      {param-value: "14", required: true})
    
    true))

;; Initialize contract with owner as first arbitrator and default templates
(map-set arbitrators CONTRACT-OWNER true)
(init-default-templates)