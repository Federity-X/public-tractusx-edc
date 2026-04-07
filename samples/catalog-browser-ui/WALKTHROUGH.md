# EDC Admin Panel — Designer Walkthrough Guide

> **Audience:** Designers, product owners, and non-technical stakeholders  
> **Jira:** [BE-170](https://dsaas-tvs.atlassian.net/browse/BE-170)  
> **Branch:** [`BE-170/edc-admin-panel-ui-on-dcp-v2`](https://github.com/Federity-X/public-tractusx-edc/tree/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui)  
> **What this is:** 25 standalone HTML pages that together form a complete mockup of an Eclipse Dataspace Connector (EDC) management portal. Every page works in your browser — no server, no build step required.

---

## How to View the Mockups

1. Open the `samples/catalog-browser-ui/` folder in Finder (macOS) or Explorer (Windows).
2. Double-click **`index.html`** — it opens in your browser and serves as the home page.
3. Click any link or button to navigate between pages. All navigation is wired up.

> **Tip:** You can also run a local server for a smoother experience:  
> Open Terminal in this folder and run `python3 -m http.server 8765`, then visit `http://localhost:8765`.

---

## Visual Theme

All pages use the **Tabler** design system with the Catena-X / Tractus-X color palette:

| Token      | Color                     | Usage                                      |
| ---------- | ------------------------- | ------------------------------------------ |
| Primary    | `#0054a6` (Catena-X blue) | Buttons, links, active states, focus rings |
| Success    | `#2fb344` (green)         | Completed, active, valid                   |
| Warning    | `#f59f00` (amber)         | Expiring, in-progress, provisioning        |
| Danger     | `#d63384` (pink-red)      | Failed, terminated, expired, delete        |
| Muted      | `#64748b` (slate gray)    | Labels, secondary text, timestamps         |
| Border     | `#e6e7e9`                 | Table borders, dividers, card edges        |
| Background | `#f8fafc`                 | Page background, light fills               |
| Dark       | `#1e293b`                 | Headings, body text                        |

**Font stack:** System fonts (`-apple-system`, `Segoe UI`, `Roboto`, etc.)

---

## Page-by-Page Walkthrough

### 1. Dashboard — `index.html`

The **home page** and navigation hub.

**What you see:**

- **Sidebar** on the left with icon links to every section (Assets, Policies, Contracts, Catalog, Negotiations, Agreements, Transfers, EDR Tokens, BPN Groups, Settings). Each icon shows a count badge.
- **Health status bar** at the top showing Control Plane, Data Plane, Vault, IdentityHub, and BDRS Client with green/amber/red dots.
- **8 stats cards** in a grid — one per module (e.g., "42 Assets", "18 Policies") with color-coded left borders.
- **Quick Actions** row — shortcut buttons like "Create Asset", "Browse Catalog", "Start Negotiation".
- **Recent Activity** timeline on the right — a chronological feed of system events with colored dots.

**Navigation:** Click any card, sidebar link, or quick-action button to jump to that section.

---

### 2. Assets

#### 2a. Asset List — `assets-list.html`

A **searchable, sortable table** of all data assets.

- **Search bar** with magnifying glass icon and a **status filter** dropdown.
- **Table columns:** Asset ID, Name, Description, Status (badge), Type, Created Date, Actions (edit/delete icons).
- **Sortable headers** — click a column header to sort ascending/descending.
- Breadcrumb: Dashboard → Assets.

#### 2b. Create Asset — `create-asset.html`

A **form page** for registering a new data asset.

- Two-column layout with labeled fields (Name, Description, Data Category, etc.).
- Required fields are marked with a red asterisk.
- Help hints below each field explain what to enter.
- Buttons: **Create** (primary blue) and **Cancel** (outline).

#### 2c. Asset Details — `asset-details.html`

A **read-only detail page** for a single asset.

- Metadata displayed in a clean two-column grid (ID, name, type, status badge, created date).
- **JSON viewer** section showing the raw asset payload in a dark code block.
- Action buttons: **Edit**, **Delete**.

#### 2d. Edit Asset — `asset-edit.html`

A **3-step wizard** for editing an asset:

1. **General Information** — name, description, category
2. **Technical Details** — endpoints, format, content type
3. **Review & Save** — summary of changes

The step indicator shows numbered circles connected by a line. Completed steps turn green with a checkmark.

---

### 3. Policies

#### 3a. Policy List — `policies-list.html`

A **data table** of all access/usage policies.

- **Stats row** at the top: Total Policies, Unrestricted, With Constraints, BPN Restricted.
- **Filters:** Search box, Type dropdown (Unrestricted, BPN Restricted, Membership, etc.), Constraint count filter.
- **Bulk actions bar** appears when you check rows — Export, Clone, Delete.
- **Badges** indicate policy type: green (unrestricted), blue (membership), orange (time-restricted), red (denied).
- Pagination with page numbers and per-page selector.

#### 3b. Create Policy — `create-policy.html`

A **3-step wizard** for policy creation:

1. **Basic Info** — policy ID, description, type
2. **Constraints** — add rules (permissions, prohibitions, obligations)
3. **Review** — summary with JSON preview

#### 3c. Policy Details — `policy-details.html`

- Policy metadata grid (ID, type, created date, status badge).
- **Rules section** showing permissions and constraints in formatted cards.
- **JSON viewer** with the full ODRL policy payload.
- Action buttons: Edit, Delete.

#### 3d. Edit Policy — `policy-edit.html`

Same 3-step wizard as Create, but pre-filled with current policy values.

---

### 4. Contract Definitions

#### 4a. Contracts Dashboard — `contracts-dashboard.html`

A **list page** for contract definitions (the rules that govern which assets + policies are offered).

- **Stats bar:** Total, Active, Archived counts.
- **Filter card** with dropdowns and search.
- **Table:** Contract ID, Name, Linked Policies, Linked Assets, Type, Status, Created Date, Actions.

#### 4b–4c. Contract Definition Builder — `contract-definition-builder.html`

A **split-screen builder**:

- **Left panel:** Form fields (contract ID, access policy, contract policy, asset selector).
- **Right panel:** Live JSON preview that updates as you fill in the form.
- A **Copy** button on the JSON preview for pasting into API tools.
- Bold gradient header (purple → pink).

> `contract-definition-builder-1.html` is a second variant with the same layout.

---

### 5. Catalog & Negotiation (Consumer Flow)

#### 5a. Browse Catalog — `catalog-browse.html`

The **discovery page** where you search for data offered by other connectors.

- **Supplier selector** — pick which remote connector to query.
- **Search/filter controls** for narrowing results.
- **Asset cards** showing Name, Type, Description, Provider BPN.
- **"Negotiate" button** on each card — clicking it takes you to the Contract Negotiation page with the asset pre-selected.

#### 5b. Contract Negotiation — `contract-negotiation.html`

A **form page** for initiating a negotiation.

- Select the asset, counterparty, and policy terms.
- Info/warning alert boxes guide you through the process.
- On submission, the negotiation appears in the Negotiations list.

---

### 6. Negotiations

#### 6a. Negotiations List — `negotiations-list.html`

A **real-time list** of all contract negotiations.

- **Auto-refresh toggle** (checkbox) for live updates.
- **Stats grid:** Total, Requesting, Agreed, Finalized, Terminated — each card has a colored left border.
- **Table columns:** Negotiation ID, Counterparty, Asset, State (badge), Role, Created, Actions.
- **State badges:** Initial (gray), Requesting (blue), Agreed (green), Finalized (dark green), Terminated (red).
- **cURL card** at the bottom showing the raw API call.

#### 6b. Negotiation Details — `negotiation-details.html`

A **detail page** with rich visualization:

- **State machine diagram** — a row of circles connected by lines. The current state is highlighted in blue; completed states are green; failed states are red.
- **Detail grid:** Negotiation ID, Protocol, Direction, Counterparty, Asset.
- **Tabs:** Details, Messages, History — each with different content:
  - Messages tab has a timeline of protocol exchanges.
  - History tab shows an audit log.
- **cURL card** with the API endpoint.

---

### 7. Agreements

#### 7a. Agreements List — `agreements-list.html`

A **list page** of finalized contract agreements.

- **Stats grid:** Total, Active, Retired, As Provider.
- **Table columns:** Agreement ID, Asset, Counterparty, Status, Type, Expires, Actions.
- **Status badges:** Active (green), Retired (gray with strikethrough).
- **Role badges:** Provider (purple), Consumer (orange).
- **Retire button** opens a **confirmation modal** (dark overlay with a centered card asking "Are you sure?").

#### 7b. Contract Details — `contract-details.html`

- Agreement metadata (ID, status, counterparty, dates).
- **Sections:** General Info, Linked Assets, Policy Terms.
- Action buttons: Download, View Transfers, Retire.

---

### 8. Data Transfers

#### 8a. Transfer History — `transfers-history.html`

A **list page** of all data transfers.

- **Auto-refresh toggle** and Export button in the header.
- **Stats cards:** Total (blue border), Completed (green), In Progress (amber), Failed (red).
- **Filters:** Search, State, Type (Pull/Push), Date Range.
- **Table columns:** Transfer ID, State (badge), Type (badge), Asset ID, Consumer BPN, Started, Duration, Progress (bar), Actions.
- **State badges** for 8+ states: Completed, Started, Requested, Provisioned, Provisioning, Terminated, Suspended, Failed, Initial.
- **Type badges:** Pull (blue), Push (green).
- **Progress bars** — colored fill based on state (blue = in progress, green = completed, red = failed).

#### 8b. Transfer Details — `transfer-details.html`

- Transfer metadata with progress indicator.
- **Timeline** showing events with colored dots and timestamps.
  - Active event has a **pulsing blue dot** animation.
- **Tabs:** Details, Events, Logs, cURL.
- Error banner (red) if the transfer failed.

#### 8c. Initiate Transfer — `initiate-transfer.html`

A **3-step wizard** for starting a new data transfer:

1. **Select Agreement** — choose the contract agreement to transfer under
2. **Configure** — set destination endpoint, transfer type (pull/push), properties
3. **Review & Submit** — summary of all settings

---

### 9. EDR Tokens

#### 9a. EDR Management — `edr-management.html`

Manage **Endpoint Data Reference** tokens (the access credentials for transferred data).

- **Stats grid:** Total, Valid (green), Expiring Soon (amber), Expired (red).
- **Table columns:** Transfer ID, Agreement, Asset, Status, Created, Expires, Actions.
- **Token field** — masked by default (`•••••••`), click to reveal the JWT.
- **Detail drawer** — a slide-in side panel showing full token data and JSON payload.
- **Actions:** View, Refresh, Revoke, Copy, Download.
- **Toast notifications** (bottom-right popups) for copy/refresh/revoke feedback.

#### 9b. Data Pull Viewer — `data-pull-viewer.html`

An **interactive testing tool** with a 3-step wizard:

1. **Select EDR** — pick from available EDR tokens in a dropdown, see endpoint preview.
2. **Review Endpoint** — inspect the target URL and auth token (with copy button).
3. **Execute & View Response** — fire the HTTP request and see the response body, status code, latency, and size.

- **Mock responses** include realistic Catena-X data (battery chemistry, PCF data, quality alerts).
- **Request history** panel tracks past requests with timestamps.
- Supports deep linking from EDR Management via `?tp=` URL parameter.

---

### 10. BPN Group Management — `bpn-groups.html`

Manage **Business Partner Number** groups for policy-based access control.

**Two-panel layout:**

- **Left panel — Groups list:**
  - Scrollable list of groups (e.g., "gold-partners", "tier-1-suppliers", "pcf-exchange").
  - Each group shows its name and a member count badge.
  - Click a group to select it (highlighted with a blue left border).

- **Right panel — Members table:**
  - Shows BPN entries for the selected group.
  - **Add BPN form** at the top with validation (must match `BPNL` + 12 alphanumeric characters).
  - **Table columns:** BPN, Name, Type, Added Date, Actions (edit/delete).

- **Modals:** Create Group, Edit Member, Delete Confirmation.
- **cURL cards** showing API calls for creating entries and resolving BPNs.

---

### 11. Connector Settings — `connector-settings.html`

System configuration and health monitoring.

- **Health status bar** at the top with colored dots:
  - 🟢 Green = Healthy (Control Plane, Data Plane, Vault, IdentityHub)
  - 🟡 Amber = Degraded (BDRS Client — 210ms latency)
  - 🔴 Red = Down

- **Configuration cards** in a 2-column grid:
  - **Identity & Protocol:** Participant ID (BPN), DID, DCP/DSP protocol versions, EDC version.
  - **Endpoints:** Management API, Protocol API, Public API URLs.
  - **Vault Configuration:** Connection details, encryption info.
  - **API Key:** Masked field with Reveal/Copy/Rotate buttons.

- **Connection Test** section — a table of automated tests (Control Plane reachable, Vault authenticated, etc.) with pass/fail indicators and latency.

---

## Navigation Map

```
index.html (Dashboard)
├── assets-list.html
│   ├── create-asset.html
│   ├── asset-details.html
│   │   └── asset-edit.html
│   └── asset-edit.html
├── policies-list.html
│   ├── create-policy.html
│   ├── policy-details.html
│   │   └── policy-edit.html
│   └── policy-edit.html
├── contracts-dashboard.html
│   ├── contract-definition-builder.html
│   └── contract-definition-builder-1.html
├── catalog-browse.html
│   └── contract-negotiation.html
├── negotiations-list.html
│   └── negotiation-details.html
├── agreements-list.html
│   ├── contract-details.html
│   └── initiate-transfer.html
├── transfers-history.html
│   ├── transfer-details.html
│   └── initiate-transfer.html
├── edr-management.html
│   └── data-pull-viewer.html
├── bpn-groups.html
└── connector-settings.html
```

---

## Common UI Patterns

| Pattern                 | Where Used                                                          | Description                                                         |
| ----------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **Stats cards**         | Most list pages                                                     | Color-coded cards at the top showing key counts                     |
| **Data table**          | Assets, Policies, Negotiations, Agreements, Transfers, EDR, BPN     | Sortable, searchable tables with pagination                         |
| **Step wizard**         | Create/Edit Asset, Create/Edit Policy, Initiate Transfer, Data Pull | Numbered circles with connecting lines; step content switches       |
| **Badges**              | Everywhere                                                          | Colored pills for status, type, role (green/blue/amber/red/gray)    |
| **cURL cards**          | Negotiations, Agreements, Transfers, EDR, BPN                       | Dark code block showing the real API call with a Copy button        |
| **Breadcrumbs**         | All pages                                                           | "Dashboard > Section > Page" links at top for navigation context    |
| **Modals**              | Agreements (retire), BPN (create/edit/delete)                       | Dark overlay with centered card, Cancel/Confirm buttons             |
| **Detail drawer**       | EDR Management                                                      | Side panel sliding in from the right with full token details        |
| **Toast notifications** | EDR, BPN, Catalog                                                   | Bottom-right popup confirming an action (fades after a few seconds) |
| **Auto-refresh**        | Negotiations, Transfers                                             | Checkbox that enables polling every 30 seconds                      |
| **Split-screen**        | Contract Builder                                                    | Form on left, live JSON preview on right                            |
| **State machine**       | Negotiation Details                                                 | Visual circles + connecting lines showing protocol states           |
| **Progress bars**       | Transfer History                                                    | Fill bar colored by state (blue/green/red)                          |
| **Token masking**       | EDR, Settings                                                       | `•••••••` by default with reveal toggle                             |

---

## Glossary for Non-Technical Readers

| Term                    | What It Means                                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| **EDC**                 | Eclipse Dataspace Connector — the software that enables secure data sharing between organizations |
| **Asset**               | A piece of data or an API endpoint that can be shared with partners                               |
| **Policy**              | Rules that control who can access an asset and under what conditions                              |
| **Contract Definition** | Combines an asset with policies to create an "offer" for the catalog                              |
| **Catalog**             | The marketplace where other connectors can discover your data offers                              |
| **Negotiation**         | The handshake process where two connectors agree on terms before sharing data                     |
| **Agreement**           | The finalized contract after a successful negotiation                                             |
| **Transfer**            | The actual movement of data between connectors after an agreement is in place                     |
| **EDR**                 | Endpoint Data Reference — the access token + URL needed to retrieve transferred data              |
| **BPN**                 | Business Partner Number — a unique ID for every organization in the Catena-X network              |
| **ODRL**                | Open Digital Rights Language — the standard used to express policies                              |
| **DID**                 | Decentralized Identifier — a self-owned identity like `did:web:example.com`                       |
| **cURL**                | A command-line tool for making API calls — shown in the mockups for developer reference           |

---

## File Inventory

> Click a filename to view it on GitHub.

| #   | File                                 | Page Title                 |
| --- | ------------------------------------ | -------------------------- |
| 1   | [`index.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/index.html)                         | Dashboard                  |
| 2   | [`assets-list.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/assets-list.html)                   | Asset List                 |
| 3   | [`create-asset.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/create-asset.html)                  | Create Asset               |
| 4   | [`asset-details.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/asset-details.html)                 | Asset Details              |
| 5   | [`asset-edit.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/asset-edit.html)                    | Edit Asset                 |
| 6   | [`policies-list.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/policies-list.html)                 | Policy List                |
| 7   | [`create-policy.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/create-policy.html)                 | Create Policy              |
| 8   | [`policy-details.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/policy-details.html)                | Policy Details             |
| 9   | [`policy-edit.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/policy-edit.html)                   | Edit Policy                |
| 10  | [`contracts-dashboard.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/contracts-dashboard.html)           | Contract Definitions       |
| 11  | [`contract-definition-builder.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/contract-definition-builder.html)   | Contract Builder           |
| 12  | [`contract-definition-builder-1.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/contract-definition-builder-1.html) | Contract Builder (v2)      |
| 13  | [`catalog-browse.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/catalog-browse.html)                | Catalog Browse             |
| 14  | [`contract-negotiation.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/contract-negotiation.html)          | Contract Negotiation       |
| 15  | [`negotiations-list.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/negotiations-list.html)             | Negotiations List          |
| 16  | [`negotiation-details.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/negotiation-details.html)           | Negotiation Details        |
| 17  | [`agreements-list.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/agreements-list.html)               | Agreements List            |
| 18  | [`contract-details.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/contract-details.html)              | Contract/Agreement Details |
| 19  | [`transfers-history.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/transfers-history.html)             | Transfer History           |
| 20  | [`transfer-details.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/transfer-details.html)              | Transfer Details           |
| 21  | [`initiate-transfer.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/initiate-transfer.html)             | Initiate Transfer          |
| 22  | [`edr-management.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/edr-management.html)                | EDR Token Management       |
| 23  | [`data-pull-viewer.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/data-pull-viewer.html)              | Data Pull Viewer           |
| 24  | [`bpn-groups.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/bpn-groups.html)                   | BPN Group Management       |
| 25  | [`connector-settings.html`](https://github.com/Federity-X/public-tractusx-edc/blob/BE-170/edc-admin-panel-ui-on-dcp-v2/samples/catalog-browser-ui/connector-settings.html)            | Connector Settings         |
