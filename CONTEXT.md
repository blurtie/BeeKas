# BeeKas

BeeKas is a marketplace for the BINUS community to sell and donate used goods. This glossary covers onboarding, registration, and sign-in.

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
