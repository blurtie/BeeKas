# BeeKas

BeeKas is a marketplace for the BINUS community to sell and donate used goods. This glossary covers onboarding, registration, sign-in, and orders.

## Language

**Member**:
A person with a BeeKas account tied to one active BINUS email.
_Avoid_: user (too broad; includes guests), customer

**Guest**:
A person using the app without an account. Can browse the catalog only.
_Avoid_: anonymous user, visitor

**Admin**:
A member with the admin role who reviews verification submissions. Admin accounts are created by the team, never through registration.
_Avoid_: moderator, reviewer

**BINUS email**:
An email address on `@binus.ac.id` or `@binus.edu`. The only email accepted for registration.
_Avoid_: campus email, student email

**Member type**:
Whether a member is a student, lecturer, or staff. Derived from the BINUS email domain: `@binus.ac.id` is always student; `@binus.edu` is lecturer or staff, chosen by the member. Determines which identity card is requested. There is no alumni type.
_Avoid_: role (reserved for admin vs member), affiliation, user type

**Campus**:
The campus area a member belongs to, one of a fixed list (Kemanggisan, Senayan, Alam Sutera, BASE, Bekasi, Bandung, Malang, Semarang, BINUS Online). Nearby campuses are merged into one area.
_Avoid_: location, branch

**Identity card**:
The physical BINUS card a member photographs: Flazz for students, lecturer ID card, or staff ID card.
_Avoid_: KTM, ID, Flazz (as the general term)

**Card photo**:
A camera photo of the member's identity card, taken in the app.

**Selfie**:
A front-camera photo of the member's face, compared by an admin with the face on the card photo.
_Avoid_: face scan, liveness check (no automated check exists)

**Verification submission**:
One card photo plus one selfie sent for review. A rejected member may send a new submission.
_Avoid_: application, document

**Verification review**:
An admin's decision on a submission: approve, or reject with a reason.

**Account status**:
Where a member stands in verification: `incomplete`, `pending`, `approved`, or `rejected`. A guest has no account status.
- **Incomplete**: email verified and password set; no submission sent yet.
- **Pending**: a submission awaits review.
- **Approved**: verified; full access.
- **Rejected**: the last submission was rejected; the member may resubmit.
_Avoid_: verified/unverified (ambiguous between email and identity)

**Email verification**:
Proving ownership of the BINUS email by entering a 6-digit code sent to it. Happens before an account exists.
_Avoid_: identity verification (that is the card and selfie)

**Identity verification**:
The card photo, selfie, and verification review together.

**Sign-in identifier**:
The BINUS email or phone number a member types to sign in.

**Order (Pesanan)**:
An approved member's claim on one unit of a listing, by **Booking 24 Jam** or **Beli Sekarang**, paid by COD on campus. Status: Menunggu (waiting for the seller), Diproses, Selesai, or Dibatalkan.
_Avoid_: transaction, purchase (a booking is not a purchase)

**Booking 24 Jam**:
An order that holds one unit for 24 hours without a promise to buy. The seller may extend the hold once by 24 hours at the buyer's request.
_Avoid_: reservation, keep

**Beli Sekarang**:
An order that promises to buy one unit at the listing price when ordered.
_Avoid_: checkout (that is the screen), instant buy

**Running order (Pesanan berjalan)**:
An order that is Menunggu or Diproses. A buyer has at most one per listing and at most 2 on donations.
_Avoid_: active order, open order

**Hold**:
How long a Menunggu order waits for the seller (`hold_until`): 24 hours from ordering. When it runs out the order is cancelled automatically and the unit returns to stock.
_Avoid_: timer, deadline

**Lokasi COD**:
Where buyer and seller meet: a **Campus** plus optional free text. Set by the buyer when ordering; either party may change it until Selesai.
_Avoid_: shipping address, delivery address

**Waktu COD**:
The date and time of the meeting. Set by the seller on Terima; either party may change it while Diproses. The order completes automatically 3 days after it.
_Avoid_: delivery time

**Cancel reason (Alasan batal)**:
A fixed code (changed mind, not as described, can't meet, sold elsewhere, other) plus a note, required for Other. An automatic cancel has no reason.
_Avoid_: rejection reason (that is for verification)

## Relationships

- A **Member** has exactly one **BINUS email** and one unique phone number
- A **Member** has one **Member type** and one **Campus**
- A **Member** has zero or more **Verification submissions**; only the latest one counts
- An **Admin** makes a **Verification review** on a **Verification submission**
- **Account status** moves: incomplete → pending → approved, or pending → rejected → pending

## Example dialogue

> **Dev:** "Can a **Guest** see the seller's WhatsApp number?"
> **Domain expert:** "No. Guests and members who are **pending** or **rejected** only browse the catalog. Only **approved** members can contact sellers or list items."

## Flagged ambiguities

- "Verifikasi" in the notes meant both **Email verification** and **Identity verification**. They are separate steps.
- "ID card" in the notes meant the physical **Identity card**; the "temporary digital ID card" from the notes was dropped (D-14).
