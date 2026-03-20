# Merge origin/main → feature/2678 — TODO List

> **Last updated**: Deep-dive analysis complete. All items verified against simulated merge tree.

## Context

Three new commits landed on `origin/main` since our branch point (`ba45ef3fe`):

| Commit | Title | Impact on our PR |
|--------|-------|-----------------|
| `fe3ccdc49` | feat: Rename dim to div (#2672) | **CRITICAL** — renames all DIM→DIV across 49 files |
| `838e76360` | feat: exchange identity extractor (#2677) | **NONE** — no file overlap with our PR |
| `2ab6041e6` | feat: remove federated catalog (#2575) | **LOW** — auto-merge clean, removes FC module |

## Merge Conflict Summary (5 content + 1 file-location)

Trial merge (`git merge --no-commit --no-ff origin/main`) produces 6 conflicts:

| # | File | Conflict Type |
|---|------|--------------|
| 1 | `settings.gradle.kts` | content — module name `dim` vs `div` + our `identityhub` line |
| 2 | `edc-controlplane/edc-controlplane-base/build.gradle.kts` | content — dependency naming |
| 3 | `.../DidDocumentServiceDivClientExtension.java` | content — our review fixes vs their mechanical rename |
| 4 | `.../did-document-service-div/README.md` | content — our added sections vs their DIM→DIV rename |
| 5 | `.../IatpParticipant.java` | content — our `client.type` line vs their `dimUri→divUri` rename |
| 6 | `.../DidDocumentServiceDimClientExtensionTest.java` | file location — created in old `dim/` dir (renamed to `div/`) |

---

## CRITICAL Decision: Client Type Value — `dim` or `div`?

The DIM→DIV rename changed **module names**, **class names**, **config property keys** (`tx.edc.iam.sts.dim.url` → `tx.edc.iam.sts.div.url`), but the upstream did NOT have our `tx.edc.did.service.client.type` selector (we introduced it).

**We must decide**: should the client type value be `"div"` (matching the new naming) or remain `"dim"` (backward-compatible)?

**Recommendation**: Change to `"div"` for consistency. Since this is a **new** property (didn't exist before our PR), there's no backward-compat concern. The entire DIM→DIV rename is upstream's breaking change.

This decision affects **40+ locations** across ~15 files (listed below).

---

## Deep-Dive Verification Results

Items verified during simulated merge analysis:

| Area | Status | Notes |
|------|--------|-------|
| META-INF ServiceExtension (DIV) | ✅ OK | Upstream already updated content to `DidDocumentServiceDivClientExtension` |
| META-INF ServiceExtension (IH) | ✅ OK | Our `DidDocumentServiceIdentityHubClientExtension` reference is correct |
| `tx-dcp-sts-div` build dep | ✅ OK | Inside renamed dir, auto-resolved to `tx-dcp-sts-div` |
| `runtime-memory-iatp-div-ih` module | ✅ OK | Auto-merged: `settings.gradle.kts:150`, `iatp-tests/build.gradle.kts:56`, `Runtimes.java:39` |
| `DidDocumentServiceDivClient.java` | ✅ OK | Upstream renamed; we never modified this file — clean auto-merge |
| Helm `gotmpl` templates | ✅ OK | Our branch didn't modify these; upstream DIM→DIV changes apply cleanly |
| Helm Chart READMEs (`README.md`) | ✅ OK | Our branch didn't modify these; auto-generated from gotmpl |
| `TractusxIatpParticipantBase` base class | ⚠️ CRITICAL | Field renamed `dimUri` → `divUri`. Our `IatpParticipant` code references `dimUri` which **no longer exists** — will not compile! |
| `DimOauth2Client` → `DivOauth2Client` | ⚠️ ACTION | Upstream renamed the class. Our test imports `DimOauth2Client` — must update |
| Historical migration docs (2024-05) | ✅ SKIP | `TX_EDC_IAM_STS_DIM_URL` reference is intentionally historical — do not change |
| `docs/migration/2025-06-Version_0.9.x_0.10.x.md` | ✅ SKIP | References "DIM" in upstream's migration context — not ours to change |

---

## TODO Items

### PRIORITY 1: Conflict Resolution (6 files)

- [ ] **1.1** `settings.gradle.kts` — Resolve: use `did-document-service-div` (not `dim`) + add `did-document-service-identityhub`
  - OURS: `include(":edc-extensions:did-document:did-document-service-dim")` + `include(":edc-extensions:did-document:did-document-service-identityhub")`
  - THEIRS: `include(":edc-extensions:did-document:did-document-service-div")`
  - RESULT: both `did-document-service-div` AND `did-document-service-identityhub`

- [ ] **1.2** `edc-controlplane/edc-controlplane-base/build.gradle.kts` — Resolve: `did-document-service-div` + `did-document-service-identityhub`
  - OURS: `implementation(project(":edc-extensions:did-document:did-document-service-dim"))` + identityhub line
  - THEIRS: `implementation(project(":edc-extensions:did-document:did-document-service-div"))`
  - RESULT: both `did-document-service-div` AND `did-document-service-identityhub`

- [ ] **1.3** `DidDocumentServiceDivClientExtension.java` — Merge our review improvements into upstream's renamed version
  - **Our additions to merge in** (updating DIM→DIV as needed):
    - `@Provides` comment → update reference: `DidDocumentServiceDivClientExtension`
    - `CLIENT_TYPE_DIV = "div"` constant (was `CLIENT_TYPE_DIM = "dim"`)
    - `clientType` check guard block **before** the `divUrl` null check
    - `@Setting` annotation for `tx.edc.did.service.client.type`
    - `monitor.warning()` (not `monitor.info()`) for missing URL/OAuth **after** the type-match guard
    - Log messages: `"DidDocumentServiceDIVClient"`, `"DIV URL not configured"`, `"DivOauth2Client"`
  - **Their changes to preserve**:
    - Class name: `DidDocumentServiceDivClientExtension`
    - `DivOauth2Client` (not `DimOauth2Client`), field name `divOauth2Client`
    - `divUrl` field, config key `tx.edc.iam.sts.div.url`
    - `DidDocumentServiceDivClient` constructor call
    - `getHostWithScheme(divUrl)` call
  - **Upstream has NONE of our review fixes**: no `CLIENT_TYPE`, no `clientType` guard, no `@Setting` for selector, no `@Provides` comment, no `monitor.warning()` — all must be merged in.

- [ ] **1.4** `did-document-service-div/README.md` — Merge our extra sections into upstream's renamed README
  - Upstream has: Overview + 4 API sections + auth note (all DIM→DIV renamed)
  - We added: Activation, Configuration, Client Type Selector, Helm Configuration sections
  - Resolution: Take upstream's base (with DIV naming), append our sections with DIM→DIV updates:
    - `tx.edc.did.service.client.type=dim` → `tx.edc.did.service.client.type=div`
    - `DimOauth2Client` → `DivOauth2Client`
    - `tx.edc.iam.sts.dim.url` → `tx.edc.iam.sts.div.url`
    - `clientType: "dim"` → `clientType: "div"`

- [ ] **1.5** `IatpParticipant.java` — ⚠️ **CRITICAL COMPILATION FIX** — Merge our `client.type` with their `dim→div` rename
  - **CRITICAL**: `TractusxIatpParticipantBase` renamed `dimUri` → `divUri`. Our code uses `dimUri` which **does not exist** in the base class. Will fail to compile.
  - OURS: `if (dimUri != null) { settings.put("tx.edc.iam.sts.dim.url", dimUri.get()...); settings.put("tx.edc.did.service.client.type", "dim"); }`
  - THEIRS: `if (divUri != null) { settings.put("tx.edc.iam.sts.div.url", divUri.get()...); }`
  - RESULT: `if (divUri != null) { settings.put("tx.edc.iam.sts.div.url", divUri.get().toString()); settings.put("tx.edc.did.service.client.type", "div"); }`
  - Also confirmed upstream has **both** `dimUri` (deprecated, backward compat) and `divUri` (new) in base class, but the config key is now `tx.edc.iam.sts.div.url` — our fixture should use `divUri`.

- [ ] **1.6** `DidDocumentServiceDimClientExtensionTest.java` — File location conflict
  - Our test created at `did-document-service-dim/src/test/.../DidDocumentServiceDimClientExtensionTest.java`
  - Upstream renamed directory to `did-document-service-div/`
  - Git moves the file into `div/` but keeps old name + content
  - Action: Rename file to `DidDocumentServiceDivClientExtensionTest.java` + full content rewrite (see TODO 2.3)

### PRIORITY 2: DIM→DIV Renames in Our Files (non-conflict, but must update)

- [ ] **2.1** `DidDocumentServiceDimClient.java` → `DidDocumentServiceDivClient.java`
  - Class renamed by upstream; we never modified this file — auto-merged cleanly.
  - ✅ No action. Just verify it compiled correctly.

- [ ] **2.2** `DidDocumentServiceDivClientExtensionTest.java` — Full content rewrite (after file rename from 1.6)
  - **Class rename**: `DidDocumentServiceDimClientExtensionTest` → `DidDocumentServiceDivClientExtensionTest`
  - **Import**: `org.eclipse.tractusx.edc.iam.dcp.sts.dim.oauth.DimOauth2Client` → `...div.oauth.DivOauth2Client`
  - **Constant**: `DIM_URL` → `DIV_URL`, value stays `"https://dim.example.com/api/v1"` (or update to `div.example.com`)
  - **Field**: `DimOauth2Client dimOauth2Client` → `DivOauth2Client divOauth2Client`
  - **Mock**: `mock(DimOauth2Client.class)` → `mock(DivOauth2Client.class)`
  - **registerService**: `DimOauth2Client.class, dimOauth2Client` → `DivOauth2Client.class, divOauth2Client`
  - **Config values**: `"tx.edc.did.service.client.type", "dim"` → `"div"` ; `"tx.edc.iam.sts.dim.url"` → `"tx.edc.iam.sts.div.url"`
  - **Method names**: `shouldRegisterClient_whenClientTypeIsDim` → `...IsDiv`, `shouldNotRegister_whenDimUrlMissing` → `...DivUrlMissing`
  - **Assertions**: `DidDocumentServiceDimClient.class` → `DidDocumentServiceDivClient.class`
  - **Verify logs**: `"is not set to 'dim'"` → `"'div'"`, `"DIM URL not configured"` → `"DIV URL not configured"`
  - **Constructor ref**: `DidDocumentServiceDimClientExtension.class` → `DidDocumentServiceDivClientExtension.class`
  - **settings.remove**: `"tx.edc.iam.sts.dim.url"` → `"tx.edc.iam.sts.div.url"`
  - Total: **~15 distinct changes** within the test file

- [ ] **2.3** SPI `DidDocumentServiceClient.java` — Update Javadoc
  - Line 66: `Valid values: {@code "dim"}, {@code "identityhub"}.` → `Valid values: {@code "div"}, {@code "identityhub"}.`

- [ ] **2.4** IH extension `DidDocumentServiceIdentityHubClientExtension.java` — Update DIM references
  - Line ~42 comment: `DidDocumentServiceDimClientExtension` → `DidDocumentServiceDivClientExtension`
  - Line ~76 `@Setting` description: `e.g. 'dim', 'identityhub'` → `e.g. 'div', 'identityhub'`

- [ ] **2.5** IH extension test `DidDocumentServiceIdentityHubClientExtensionTest.java`
  - Line ~84: `settings.put("tx.edc.did.service.client.type", "dim");` → `"div"`

- [ ] **2.6** IH `README.md` — Update DIM→DIV references
  - `"Both the DIM and IdentityHub extensions"` → `"Both the DIV and IdentityHub extensions"`
  - `tx.edc.did.service.client.type=dim → DIM client` → `tx.edc.did.service.client.type=div → DIV client`

- [ ] **2.7** Self-registration `README.md`
  - `| did-document-service-dim | SAP DIM | tx.edc.did.service.client.type=dim |` → `| did-document-service-div | SAP DIV | tx.edc.did.service.client.type=div |`

### PRIORITY 3: Documentation Updates

- [ ] **3.1** Decision record `docs/development/decision-records/2025-11-27-did-service-registration/README.md`
  - Line 28: `(\`dim\` or \`identityhub\`)` → `(\`div\` or \`identityhub\`)`
  - Line 99: `(DIM, IdentityHub, potentially others)` → `(DIV, IdentityHub, potentially others)`

- [ ] **3.2** Migration guide `docs/migration/2026_03-Version_0.11.x_0.12.x.md` — **8 changes**
  - Line 51: `TX_EDC_DID_SERVICE_CLIENT_TYPE="dim"` → `"div"`
  - Line 55: `` `dim` (for SAP DIM/DIV)`` → `` `div` (for SAP DIV)``
  - Line 58: `` `tx.edc.iam.sts.dim.url` `` → `` `tx.edc.iam.sts.div.url` ``
  - Line 59: `TX_EDC_DID_SERVICE_CLIENT_TYPE=dim` → `=div`
  - Line 60: `Existing DIM deployments` → `Existing DIV deployments`
  - Line 224: `tx-dcp-sts-dim` → `tx-dcp-sts-div`
  - Line 228: `edc.iam.sts.dim.url` / `tx.edc.iam.sts.dim.url` / `TX_EDC_IAM_STS_DIM_URL` → `div` variants
  - **Note**: Consider whether this migration guide should be rebased to the correct version boundary (0.12→0.13?) since upstream already has `0.12.x→0.13.x` guide.

- [ ] **3.3** Helm chart values comments — Update DIM references
  - `charts/tractusx-connector/values.yaml`: `'dim', 'identityhub'` → `'div', 'identityhub'`, `not DIM` → `not DIV`
  - `charts/tractusx-connector-memory/values.yaml`: same 2 changes

- [ ] **3.4** Helm chart READMEs — auto-generated from `gotmpl`; verify regeneration after merge

### PRIORITY 4: Files NOT to Change (Intentionally Historical)

These contain "DIM" references that are **intentionally historical** — do NOT update:

| File | Reason |
|------|--------|
| `docs/migration/2024-05-Version_0.5.x_0.7.x.md` | Historical migration guide documenting DIM setup as it existed in v0.5-0.7 |
| `docs/migration/2025-06-Version_0.9.x_0.10.x.md` | Historical migration guide referencing DIM in its original context |

### PRIORITY 5: Verification

- [ ] **5.1** Build the full project — `./gradlew build`
- [ ] **5.2** Run DIV extension tests — verify all 4 tests pass with `div` config values
- [ ] **5.3** Run IH extension tests — verify all 18 tests pass
- [ ] **5.4** Run SPI module compile check
- [ ] **5.5** Run e2e-fixtures compile check (critical — `IatpParticipant` must compile with `divUri`)
- [ ] **5.6** Final grep for stale `dim` references: `grep -rn '"dim"\|=dim\|'dim'\|\.dim\.\|_dim_\|_DIM_\|-dim-\|DimOauth\|DidDocumentServiceDim\|tx-dcp-sts-dim' --include="*.java" --include="*.kts" --include="*.yaml" --include="*.md"` (excluding `.git/`, historical migration docs, `MERGE-MAIN-TODO.md`)
- [ ] **5.7** Verify Helm chart README regeneration from gotmpl

### PRIORITY 6: PR Updates

- [ ] **6.1** Update PR description — DIM→DIV naming, updated test counts, breaking change wording
- [ ] **6.2** Update commit message if squashing

---

## Complete File Inventory (33 items)

### A. Files WITH merge conflicts (6) — must resolve manually:
| # | File | Conflict Type |
|---|------|--------------|
| 1 | `settings.gradle.kts` | content (module name) |
| 2 | `edc-controlplane/edc-controlplane-base/build.gradle.kts` | content (dependency name) |
| 3 | `edc-extensions/did-document/did-document-service-div/src/main/java/.../DidDocumentServiceDivClientExtension.java` | content (our review fixes vs their rename) |
| 4 | `edc-extensions/did-document/did-document-service-div/README.md` | content (our sections vs their rename) |
| 5 | `edc-tests/e2e-fixtures/src/testFixtures/java/.../IatpParticipant.java` | content (our client.type + their dimUri→divUri) |
| 6 | `edc-extensions/did-document/did-document-service-div/src/test/java/.../DidDocumentServiceDimClientExtensionTest.java` | file location (dir renamed, needs file rename + content rewrite) |

### B. Files WITHOUT conflicts needing DIM→DIV content updates (9):
| # | File | Changes |
|---|------|---------|
| 7 | `spi/did-document-service-spi/src/main/java/.../DidDocumentServiceClient.java` | Javadoc: "dim" → "div" |
| 8 | `edc-extensions/did-document/did-document-service-identityhub/src/main/java/.../DidDocumentServiceIdentityHubClientExtension.java` | Comment + @Setting desc |
| 9 | `edc-extensions/did-document/did-document-service-identityhub/src/test/java/.../DidDocumentServiceIdentityHubClientExtensionTest.java` | Config value "dim" → "div" |
| 10 | `edc-extensions/did-document/did-document-service-identityhub/README.md` | DIM→DIV references |
| 11 | `edc-extensions/did-document/did-document-service-self-registration/README.md` | Module name + config value |
| 12 | `docs/development/decision-records/2025-11-27-did-service-registration/README.md` | 2× "dim" → "div" |
| 13 | `docs/migration/2026_03-Version_0.11.x_0.12.x.md` | 8× DIM→DIV refs |
| 14 | `charts/tractusx-connector/values.yaml` | 2× comment DIM→DIV |
| 15 | `charts/tractusx-connector-memory/values.yaml` | 2× comment DIM→DIV |

### C. Files auto-merged cleanly — verified no action needed (12+):
| File | Verified |
|------|----------|
| META-INF ServiceExtension (DIV module) | ✅ Content already `DidDocumentServiceDivClientExtension` |
| META-INF ServiceExtension (IH module) | ✅ Content `DidDocumentServiceIdentityHubClientExtension` — correct |
| `did-document-service-div/build.gradle.kts` | ✅ Dep is `tx-dcp-sts-div` |
| `settings.gradle.kts` L150 (runtime) | ✅ Ref is `runtime-memory-iatp-div-ih` |
| `iatp-tests/build.gradle.kts` L56 | ✅ Ref is `runtime-memory-iatp-div-ih` |
| `Runtimes.java` L39 | ✅ Ref is `runtime-memory-iatp-div-ih` |
| `DidDocumentServiceDivClient.java` | ✅ Upstream renamed; we never modified — clean |
| Helm deployment templates (both charts) | ✅ Our additions + their DIM→DIV in different blocks |
| Helm chart `README.md` / `README.md.gotmpl` | ✅ Not modified by our branch |
| Identity extractor changes (10 files) | ✅ Zero overlap with our PR |
| Federated catalog removal (27 files) | ✅ Auto-reverses our view, no conflict |

### D. Intentionally NOT changed (historical):
| File | Reason |
|------|--------|
| `docs/migration/2024-05-Version_0.5.x_0.7.x.md` | Historical DIM references (v0.5-0.7 era) |
| `docs/migration/2025-06-Version_0.9.x_0.10.x.md` | Historical DIM references (v0.9-0.10 era) |
