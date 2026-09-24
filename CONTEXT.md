# BeeKas

Campus marketplace for the BINUS community: members list used items for sale or donation and arrange COD over WhatsApp.

## Language

**Member**: A person signed in with a BINUS email (@binus.ac.id student, @binus.edu staff).
_Avoid_: customer, account holder

**Visitor**: Someone browsing without signing in. Sees listings and campus, never seller identity or WhatsApp.

**Listing**: One item offered by a seller, either a **Sale listing** (has a price) or a **Donation listing** (no price, shown as Free).
_Avoid_: post, product, ad

**Seller** / **Buyer**: Roles a Member takes per listing; one Member can be both.

**Listing credit**: The right to publish one listing. Bought or granted, never cashed out or transferred.
_Avoid_: balance, wallet, saldo, token

**Credit ledger**: The append-only record of every credit change. A Member's credits are the sum of its entries.

**Credit adjustment**: A ledger entry an admin creates by hand, always with a written reason.

**Publish**: Turning a filled form into a live listing; costs one listing credit.

**Listing campus**: The campus where the item is, chosen by the seller when creating the listing; defaults to the seller's profile campus.

**Meetup note**: Optional short seller hint on where to meet for COD; shown only to Members.

## Relationships

- A **Member** has many **Listings** and many **Credit ledger** entries.
- **Publishing** a **Listing** creates exactly one **Credit ledger** entry of −1.
- A **Credit adjustment** is a **Credit ledger** entry made by an admin.

## Flagged ambiguities

- "kuota" (PRD) and "listing credits" (UI) mean the same thing; code uses **credits**.
