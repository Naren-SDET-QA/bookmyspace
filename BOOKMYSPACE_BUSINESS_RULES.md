# BookMySpace — Business Rules v1 (Single Source of Truth)

## Executive Overview & Core Principle
> **"The database owns availability, the server owns price/payment state, and the platform owns the booking lifecycle."**

The client application (Android / Jetpack Compose / Web) displays UI and initiates actions. It is **never** the authority for deciding slot availability, calculating final pricing, validating payment success, or driving state transitions.

---

## 1. Roles & RBAC Matrix
V1 defines four primary roles with strict server-enforced permissions:

| Role | Main Responsibility |
| --- | --- |
| **Customer / User** | Search, check availability, book/reserve, pay, cancel, review |
| **Owner** | Create & manage listings, pricing, availability calendars, record offline bookings, handle requests |
| **Admin** | Approve or reject listings, platform moderation, dispute resolution, refund oversight |
| **Platform / System** | Hold enforcement, inventory locking, payment webhooks, notifications, audit trail generation |

*Note: Test customer accounts must never inherit `venue_owner` or `admin` privileges. RBAC and Supabase Row Level Security (RLS) enforce these boundaries on the backend.*

---

## 2. Listing Lifecycle
All listings across Function Halls, Hotels/Stays, and PGs follow a strict lifecycle:

```text
Owner Creates Listing 
       ↓
     DRAFT 
       ↓
  Owner Submits 
       ↓
PENDING APPROVAL 
       ↓
  Admin Review ─── Rejected ──→ REJECTED (Reason stored, editable by owner)
       ↓
    Approved 
       ↓
   PUBLISHED ──→ Visible in Customer Search & Bookings
```

- Owners cannot self-approve or self-publish listings.
- Rejected listings store admin failure reasons and allow owner resubmission.
- Only listings with status `APPROVED` + `PUBLISHED` + `ACTIVE` appear in customer search.

---

## 3. Owner Listing Governance
- Owners control listing attributes: Name, description, address/geolocation, images, amenities, capacity, base pricing, slot schedules, contact details, and category-specific rules.
- Critical modifications to approved listings (e.g., identity, capacity changes, major pricing overhauls) trigger automatic re-review per platform moderation policy.

---

## 4. Function Hall First-Booking Architecture
First-time bookings follow the full step-by-step verification flow:

```text
Search → Hall Details → Select Date → Select Slot → Event/Guest Details → Current Price Quote → Review → Temporary Hold → Advance Payment → Confirmed → Receipt/Invoice → Notifications
```

- Client apps cannot instantiate a confirmed booking directly.
- The backend server is sole authority for availability, slot status, price calculation, taxes, discounts, totals, and booking state.

---

## 5. Online vs. Offline Booking Convergence (Single Source of Truth)
To prevent double bookings between online users and walk-in/phone bookings:

- **Single Inventory Engine**: Online holds and owner-entered offline bookings hit the exact same database inventory table and locking RPCs.
- **Online Hold**: When a customer enters checkout, the slot transitions to `TEMPORARY HOLD`.
- **Offline Walk-In**: When an owner records a walk-in, the system acquires a lock on the calendar slot.
- **First-Lock Wins**: If an online hold exists, offline entry for that slot is blocked. If an offline booking exists, online search displays the slot as unavailable.

---

## 6. Booking Hold Mechanism
- Initiating a booking places a temporary hold on the slot with a configurable expiration timer (e.g., 10 minutes).
- State progression: `AVAILABLE` → `HELD` → `PAYMENT`.
- Successful payment: `HELD` → `CONFIRMED`.
- Expired or failed payment: `HELD` → `AVAILABLE`.

---

## 7. Database-Level Double-Booking Prevention
- Concurrency protection is enforced at the database layer using atomic serializable transactions or RPC locks (e.g., `check_and_hold_slot`).
- If two users attempt to lock the same hall, date, and slot simultaneously, the database guarantees exactly one succeeds; the second receives `SLOT UNAVAILABLE`.

---

## 8. Immunity of Active Bookings
- Owners cannot delete, block, or modify slots containing active confirmed bookings.
- Attempting to block a booked date fails at the DB level or requires an explicit cancellation/dispute workflow.

---

## 9. Booking Modes: Instant vs. Owner Approval
- **Instant Booking**: `Customer Request → Payment → Confirmed`.
- **Owner Approval Mode**: `Customer Request → Owner Approves → Payment Window Opens → Confirmed`.
- Inventory holds apply during active request windows per configured policy.

---

## 10. Payment Integration & Security (Razorpay)
- Razorpay TEST mode is used for development/testing.
- Secret keys are stored in secure backend environment variables; never exposed to mobile or web clients.
- Verification flow: `Hold → Backend Order Creation → Razorpay Checkout → Backend/Webhook Verification → Confirmed`.
- Mobile client payment success signals are not accepted as proof without backend webhook confirmation.

---

## 11. Payment Webhook Idempotency
- Webhooks must process idempotently. Receiving duplicate webhooks for the same payment ID produces exactly **one** confirmed booking and **one** payment record.

---

## 12. Failed Payment Handling
- Failed payment attempts update state to `PAYMENT_FAILED`.
- Customers may retry payment while the hold timer remains active. If the timer expires, the hold releases inventory back to `AVAILABLE`.

---

## 13. Authoritative Backend Price Calculation
- The server recalculates line items (base price + taxes + platform service fee - discounts) during order creation.
- Client-submitted totals are ignored to prevent price tampering.

---

## 14. Price Snapshotting
- Active holds and confirmed bookings snapshot the quoted price at transaction time.
- Subsequent price updates by the owner apply to new inquiries only and do not affect existing quotes or bookings.

---

## 15. Platform Disintermediation & Contact Masking
- Direct owner contact information (phone number, personal email) is masked prior to booking confirmation to prevent platform bypass.
- Full owner contact details and directions release automatically upon confirmed booking and payment.

---

## 16. Repeat Booking Flow ("⚡ Book Again")
- First booking requires the full date/slot/guest selection pipeline.
- Returning customers see a "⚡ Book Again" shortcut with prefilled guest preferences.
- **Mandatory Re-validation**: "Book Again" STILL requires entering a new date, choosing an available slot, live server re-validation of current pricing, and fresh payment authorization.

---

## 17. Cancellation State Machine
- Cancellations strictly execute through a backend state engine:
  `CONFIRMED → CANCELLATION_REQUESTED → CANCELLED → REFUND_PENDING → REFUNDED`.

---

## 18. Configurable Cancellation & Refund Policies
- Refund windows and deduction percentages are driven by configurable policy tables (e.g., 100% refund > 7 days, 50% refund > 48 hours).
- Policies are presented to and accepted by customers before payment confirmation.

---

## 19. Owner-Initiated Cancellation Protocol
- Owner cancellation requires entering a mandatory cancellation reason.
- Triggers immediate customer notification, full refund processing, and slot release.
- Audit trail retains records; excessive owner cancellations impact listing ranking or trigger admin investigation.

---

## 20. Refund Integrity & Monetary Caps
- Refunds are programmatically tied to the captured payment transaction ID.
- Total refunded amount cannot exceed captured payment (`Refund ≤ Captured Amount`).
- Refund requests execute idempotently via backend API.

---

## 21. Immutability of Business Transaction History
- Financial and booking records are never deleted from the database.
- Customers maintain history tabs for Upcoming, Past, Cancelled, and Refunded stays.
- Owners and admins access corresponding transaction and audit logs.

---

## 22. Itemized Invoicing & Digital Receipts
- Upon payment confirmation, the system generates a receipt containing: Booking ID, Payment Ref, Property Name, Address, Date/Time Slot, Guest Info, Base Amount, Taxes, Platform Fees, Discounts, Total Paid, and Status.
- Cancelled/refunded orders preserve original invoice records along with refund credit notes.

---

## 23. Omnichannel Lifecycle Notifications
- Automated triggers dispatch in-app notifications and emails for key events:
  - **Customer**: Request received, Approved, Payment Success, Confirmed, Reminders, Cancelled, Refunded.
  - **Owner**: New Booking Request, Payment Confirmed, Customer Cancellation, Scheduled Visit.

---

## 24. Hotel & Stay Inventory Controls
- Stays track physical room category quantities over date ranges (`check_in` to `check_out`).
- Total active reservations for a room type cannot exceed physical capacity (`booked_rooms < capacity`).

---

## 25. Hotel Date-Range Overlap Lock
- Overlapping date range queries are locked in the database (e.g., booking Aug 10–12 blocks competing requests for Aug 11–13 if room capacity is exhausted).

---

## 26. Hotel Owner Operations
- Owners configure room types, nightly rates, total physical count, and blackout dates.
- Blacking out dates cannot override or cancel existing confirmed guest stays without going through formal cancellation.

---

## 27. PG & Co-Living Specialized Workflow
- PG Flow supports two paths:
  1. `Search → PG Details → Schedule Visit → Visit Confirmed`.
  2. `Search → Room/Bed Selection → Reserve → Pay Deposit → Confirmed`.
- Specialized parameters: Occupancy type (Single, Double, Triple), Gender designation (Men, Women, Unisex), Monthly Rent, Security Deposit, Food included, Move-in date.

---

## 28. PG Scheduled Visits
- "Schedule Visit" submits a visit request with date/time to the owner.
- Visits facilitate inspection and do **not** hold bed inventory unless converted to a paid reservation.

---

## 29. PG Bed Reservation Engine
- Inventory tracks available beds per room/occupancy type.
- Active paid reservations decrement bed inventory on the backend.

---

## 30. PG Security Deposit Protocol
- Server computes: `Total Initial Payment = First Month Rent (or partial) + Security Deposit + Reservation Fee`.
- Free/zero-deposit reservations follow direct booking request flows.

---

## 31. PG Cancellation & Deposit Refunds
- PG cancellation releases bed capacity back to the inventory pool.
- Deposit refunds follow the configured PG cancellation window policy.

---

## 32. Courses & Workshops Quick Enrollment
- Paid Course Flow: `Course → Select Batch → Enroll & Pay → Confirmed`.
- Returning Student Flow: `⚡ Enroll Now` (prefilled student details).
- Free Workshop Flow: `Course → Select Batch → Join → Confirmed`.
- Always re-verifies batch seat availability, current pricing, and payment.

---

## 33. Multi-Channel Payment Method Tracking
- The system explicitly records payment tender type: `ONLINE` (Razorpay), `CASH`, `BANK_TRANSFER`, or `OTHER`.
- Offline payment updates require authorized owner/admin credentials and generate audit entries.

---

## 34. Owner Offline Booking Management
- Owner Dashboard provides an "Add Offline Booking" interface hitting the unified inventory RPCs.
- Locks calendar dates/slots immediately, preventing online double bookings.

---

## 35. Single Authoritative Availability Calendar
- Unified state model for all listings: `AVAILABLE`, `HELD`, `BOOKED`, `BLOCKED`.
- Owner dashboard provides clear visual indicators for calendar slot statuses.

---

## 36. Admin Authority & Oversight Capabilities
- Admin powers: Approve/reject listing submissions, suspend non-compliant listings/users, review bookings/disputes, initiate manual refunds, moderate reviews.
- Financial ledgers remain immutable even under admin actions.

---

## 37. Comprehensive System Audit Trail
- Traceable log entries (`Who`, `What`, `When`, `Old State`, `New State`, `Ref ID`, `Reason`) captured for:
  - Listing approvals/rejections
  - Booking cancellations & manual refunds
  - Price changes on published listings
  - Account status suspensions & admin overrides

---

## 38. Security & Supabase RLS Enforcement
- Client-side checks are strictly UI helpers.
- Supabase Row Level Security (RLS) policies enforce data isolation:
  - **Customers** access only their own bookings, profile, and reviews.
  - **Owners** access only their properties, calendars, and incoming bookings.
  - **Admins** access elevated operational RPCs.
  - Service role keys remain protected in backend functions.

---

## 39. System-Wide Idempotency Standard
- Critical mutations (Create Booking, Acquire Hold, Webhook Consumer, Confirm Order, Cancel Booking, Process Refund) accept unique idempotency keys or transaction references to prevent duplicate execution.

---

## 40. Payment Disconnect Recovery
- If client app disconnects or crashes post-Razorpay payment, background webhooks reconcile the transaction and finalize the booking state automatically.

---

## 41. Reconciliation Engine for Orphaned Payments
- Payments captured without matching confirmed bookings are automatically flagged for automated reconciliation or placed in an admin refund queue.

---

## 42. Public Search Query Isolation
- Backend search RPCs filter strictly for `status = 'APPROVED'`, `published = true`, and `active = true` for requested categories (avoiding SQL grouping or PostgREST edge case errors).

---

## 43. Verified Booking Reviews Only
- Rating and review submissions are unlocked exclusively for users with completed booking records for that specific venue/stay/course.

---

## 44. Production Safeguards & Engineering Rules
- **Strictly Prohibited**:
  - Direct production DB wipes or destructive resets
  - Disabling or weakening RLS security policies
  - Editing existing deployed database migrations (forward-only migrations required)
  - Hardcoding secrets or API keys in source files
  - Fabricating client-side payment success without server validation

---

## 45. Primary State Machine Specifications

### Function Hall Lifecycle State Machine
```text
DRAFT / REQUESTED ──→ HELD ──→ PAYMENT_PENDING ──→ CONFIRMED ──→ COMPLETED
                       │              │                │
                    Expired        Failed          Cancelled
                       ↓              ↓                ↓
                   AVAILABLE      AVAILABLE      REFUND_PENDING ──→ REFUNDED
```

### Hotel / Stay Lifecycle State Machine
```text
REQUESTED / HELD ──→ PAYMENT_PENDING ──→ CONFIRMED ──→ CHECKED_IN ──→ COMPLETED
                                              │
                                          Cancelled ──→ REFUNDED
```

### PG / Co-Living Lifecycle State Machine
```text
Visit Track:        VISIT_REQUESTED ──→ VISIT_COMPLETED
Reservation Track:  RESERVATION_PENDING ──→ PAYMENT_PENDING ──→ CONFIRMED ──→ ACTIVE ──→ COMPLETED / MOVED_OUT
```
