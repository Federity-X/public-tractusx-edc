# Merge Plan v2: Branch from PR #8 + Cherry-Pick Local Deployment

**Date**: 2026-03-31 (v2 — strategic pivot from rebase to cherry-pick-onto-PR#8)  
**Author**: Deep analysis by AI assistant  
**Scope**: Tractus-X EDC (`tractusx-edc`) + IdentityHub (`tractusx-identityhub`)  
**Status**: **SIMULATION-VERIFIED** — full 14-commit cherry-pick completed successfully on temporary branch

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State of Play](#2-current-state-of-play)
3. [Strategy: Why Branch from PR #8](#3-strategy-why-branch-from-pr-8)
4. [Phase 1: Create dcp-v2 from PR #8](#4-phase-1-create-dcp-v2-from-pr-8)
5. [Phase 2: Cherry-Pick 14 KEEP Commits](#5-phase-2-cherry-pick-14-keep-commits)
6. [Phase 3: Post-Cherry-Pick Fixes](#6-phase-3-post-cherry-pick-fixes)
7. [Phase 4: Push IdentityHub Changes](#7-phase-4-push-identityhub-changes)
8. [Phase 5: Validation](#8-phase-5-validation)
9. [File-by-File Action Matrix](#9-file-by-file-action-matrix)
10. [Risk Register](#10-risk-register)
11. [Rollback Strategy](#11-rollback-strategy)
- [Appendix A: Cherry-Pick Simulation Log](#appendix-a-cherry-pick-simulation-log)
- [Appendix B: Quick Reference Commands](#appendix-b-quick-reference-commands)
- [Appendix C: PR #8 Additional Changes](#appendix-c-pr-8-additional-changes-outside-ih-scope)
- [Appendix D: v1 Plan Review Pass Logs (Historical)](#appendix-d-v1-plan-review-pass-logs-historical)

---

## 1. Executive Summary

We have three code streams that need to converge:

| Stream | Location | Key Content |
|--------|----------|-------------|
| **origin/main** | `Federity-X/public-tractusx-edc:main` | 3 new commits: DIM→DIV rename, identity extractor consolidation, federated catalog removal |
| **PR #8** | `origin/feature/2678-did-document-service-identityhub-v2` | IdentityHub-backed DidDocumentServiceClient v2 (cleaner, better-tested, on top of main) + deprecated API cleanup + cx-policy refactoring |
| **dcp branch** | Local `dcp` at `16bbe5a33` | IH client v1 (obsolete) + full local deployment (Docker, bootstrap, tests, Postman, docs) |

### v2 Strategy (CHANGED from v1)

**v1 plan**: Merge PR #8 into main → rebase dcp onto new main (drop 3 IH v1 commits)  
**v2 plan**: Create fresh branch from PR #8 → cherry-pick 14 local-deployment commits from dcp

**Why the pivot?**
- PR #8 branch already contains ALL of main (confirmed: `git merge-base --is-ancestor origin/main PR#8` = YES)
- PR #8 and dcp's 14 KEEP commits have **ZERO file overlap** (verified: `comm -12` on sorted file lists = empty)
- Simulation on temporary branch: **all 14 cherry-picks succeeded** with only 2 trivial modify/delete conflicts (same file, same resolution: accept deletion)
- Eliminates the complex interplay: no rebase, no merge commit handling, no Phase 1 merge step

**Additionally**: IdentityHub repo has 9 unpushed commits + 5 uncommitted files that need pushing independently.

---

## 2. Current State of Play

### 2.1 EDC Repository Topology

```
                    origin/main (2ab6041e6)
                   /                       \
  common-ancestor ── ... ── dcp (16bbe5a33)  \  [17 commits ahead of main]
                   \                          \
                    origin/feature/2678-...    (a10d58255)  [12 commits ahead of main]
                                               ↑
                                               PR #8 branch — includes all of main
                                               + IH v2 + deprecated cleanup + cx-policy
```

**Key relationship**: PR #8 is a **strict superset** of main (merge-base = main HEAD `2ab6041e6`).

**origin/main** has 3 commits not in dcp:
- `fe3ccdc49` — DIM→DIV rename (#2672): module rename `did-document-service-dim` → `did-document-service-div`, class rename, config key `tx.edc.iam.sts.dim.url` → `tx.edc.iam.sts.div.url`
- `838e76360` — Identity extractor consolidation (#2677): `BpnExtractionFunction` made standalone (no longer delegates to `DidExtractionFunction`); both `DidExtractionFunction` and `MembershipCredentialIdExtractionFunction` **DELETED** — replaced by upstream `DefaultDcpParticipantIdExtractionFunction`
- `2ab6041e6` — Remove federated catalog (#2575): removes FC extension, adds drop-table migration

**dcp** has 17 commits not on origin/main (3 DROP + 14 KEEP):
- **DROP** (3): IH DidDocumentServiceClient v1 implementation (wrong HTTP codes, autoPublish bug, DIM naming)
- **KEEP** (14): Local deployment stack — Docker, bootstrap, tests, Postman, docs, VP cache fix, DataService registration

**PR #8** (12 commits over main) adds:
- IH DidDocumentServiceClient v2 (correct codes, autoPublish fix, input validation, 41 tests)
- DIV extension guard logic (type-selector: `div` or `identityhub`)
- Self-registration improvements (better diagnostics)
- Helm chart templates for IH config
- Migration guide + decision record + READMEs
- Deprecated API cleanup (#2690) — bonus
- cx-policy refactoring — bonus

### 2.2 Zero File Overlap (Critical Finding)

```bash
# PR #8 changes 57 files vs main
# dcp's 14 KEEP commits change 24 files vs their parent
# Intersection: 0 files
$ comm -12 <(sort pr8_files.txt) <(sort keep_files.txt)  # empty
```

The only shared files are `MembershipCredentialIdExtractionFunction.java` (deleted on PR#8 base, import-only change in dcp — trivial modify/delete) and `semicolon_delimited_script` (deleted by dcp commit, exists on PR#8 — trivial).

### 2.3 IdentityHub Repository

- **Branch**: `dcp-flow-local-deployment-with-upstream-0.15.1`
- **HEAD**: `19f26de` (local) vs `f454e52` (origin) — **9 unpushed commits**
- **Working tree**: 5 modified files, 1 untracked `MERGE_PLAN.md`
- **Content**: SQL store for `ParticipantContextConfig`, security fixes, datasource config, reviewer feedback

### 2.4 Simulation Results (Verified on tmp-test-strategy branch)

Full sequential cherry-pick of all 14 KEEP commits onto PR#8 base completed successfully:

| # | Commit | Result | Notes |
|---|--------|--------|-------|
| 1 | `722907f5d` | ❌→✅ | Conflict: `MembershipCredentialIdExtractionFunction.java` modify/delete → `git rm` → resolved |
| 2 | `eba32cae9` | ✅ | Clean — creates `deployment/local/` |
| 3 | `94cbbd7b4` | ✅ | Clean — docs |
| 4 | `73ffc3d65` | ✅ | Clean — docs |
| 5 | `4cd098c51` | ✅ | Clean — Postman |
| 6 | `f05b28b52` | ✅ | Clean — Postman |
| 7 | `9eeb7d71f` | ✅ | Clean — Postman |
| 8 | `088512a58` | ✅ | Clean — Postman |
| 9 | `20964b7e2` | ✅ | Clean — docs |
| 10 | `751dceda0` | ✅ | Clean — Postman |
| 11 | `639cc484e` | ✅ | Clean — Postman |
| 12 | `c45b126b8` | ✅ | Clean — deployment |
| 13 | `0882673c2` | ❌→✅ | Conflict: same file → `git rm` → resolved. VP cache changes auto-merged. |
| 14 | `16bbe5a33` | ✅ | Clean — docs/Postman |

**Result**: 14/14 commits applied. Only 2 trivial conflicts, both with identical resolution (`git rm` the deleted file).

---

## 3. Strategy: Why Branch from PR #8

### 3.1 v1 vs v2 Strategy Comparison

| Aspect | v1 Plan (Rebase dcp onto main) | v2 Plan (Branch from PR #8) |
|--------|-------------------------------|----------------------------|
| Step count | 5 phases | 5 phases (simpler) |
| PR #8 handling | Merge into main first (separate step) | Already the base — no merge step |
| Conflict count | 2 trivial modify/delete | 2 trivial modify/delete (identical) |
| DIM→DIV rename | Needed in 2 DP configs + docs | Same (configs from dcp still have `dim`) |
| Merge commit `d8b2c8e30` | Must be handled during rebase (`--rebase-merges` or cherry-pick workaround) | N/A — only cherry-pick KEEP commits |
| File overlap | 24 KEEP files, 0 overlap with main+PR#8 | 24 KEEP files, 0 overlap with PR#8 |
| Requires main update | Yes (must merge PR#8 into main first) | No (branch directly from PR#8) |
| Risk of IH v1/v2 collision | DROP commits might clash during rebase | Impossible — v1 commits never cherry-picked |

### 3.2 Why PR #8 is Superior to dcp's IH v1

| Aspect | dcp v1 | PR #8 v2 | Impact |
|--------|--------|----------|--------|
| Naming | DIM (stale) | DIV (aligned with main) | No manual rename needed |
| `deleteById` tolerated code | 404 | 400 | **Bug fix**: IH returns 400 for "service not in DID", not 404 |
| `autoPublish` during update | Always `true` | `false` for delete phase | **Bug fix**: avoids double-publish |
| Retry lists | Broad: `[200,201,204,401,403,404,409]` | Scoped: `CREATE_SUCCESS_CODES={200,201,204,409}`, `DELETE_SUCCESS_CODES={200,204,400}` | Auth errors (401/403) correctly trigger retries |
| DID property source | `edc.iam.issuer.id` | `edc.participant.id` | Standard EDC property |
| Input validation | None | `validateService()` + URI check | Fail-fast on bad input |
| DIV guard logic | No type-selector on DIV extension | Full 3-stage guard with unknown-type warning | Clean co-existence of DIV + IH |
| Tests | ~27 | 41 | Better coverage |
| Helm charts | None | Full `values.yaml` + template validation | Production-ready |
| Documentation | Partial | Decision record, migration guide, 3 READMEs | Complete |

### 3.3 Execution Order

```
Phase 1: Create dcp-v2 branch from PR #8 (local)
Phase 2: Cherry-pick 14 KEEP commits from dcp (2 trivial conflicts)
Phase 3: Post-cherry-pick fixes (dim→div in ~8 occurrences, 5 files)
Phase 4: Push IH changes (independent)
Phase 5: Validate (build, docker, bootstrap, test-transfer)
```

### 3.4 Config Property Alignment (Verified)

PR #8's IH extension requires 5 config properties. All 5 are already present in dcp's CP configs:

| Property | PR #8 Extension Reads | consumer-cp.properties | provider-cp.properties |
|----------|----------------------|----------------------|----------------------|
| `tx.edc.did.service.client.type` | `@Setting(key=...)` | `identityhub` ✅ | `identityhub` ✅ |
| `tx.edc.ih.identity.api.url` | `@Setting(key=...)` | `http://consumer-ih:15151/api/identity` ✅ | `http://provider-ih:15151/api/identity` ✅ |
| `tx.edc.ih.identity.api.key.alias` | `@Setting(key=...)` | `consumer-ih-api-key` ✅ | `provider-ih-api-key` ✅ |
| `tx.edc.ih.participant.context.id` | `@Setting(key=...)` | `consumer` ✅ | `provider` ✅ |
| `edc.participant.id` | `@Setting(key=...)` | `did:web:consumer-ih:consumer` ✅ | `did:web:provider-ih:provider` ✅ |

**No config changes needed for the IH extension to work.**

---

## 4. Phase 1: Create dcp-v2 from PR #8

### 4.1 Pre-Flight Checks

- [ ] `git fetch origin` — ensure latest remote state
- [ ] Verify PR #8 is still based on main: `git merge-base --is-ancestor origin/main origin/feature/2678-did-document-service-identityhub-v2`
- [ ] Save backups: `git branch dcp-backup dcp` and `git branch main-backup origin/main`

### 4.2 Execution

```bash
cd /Users/wahidulazam/IdeaProjects/tractusx-edc
git fetch origin
git branch dcp-backup dcp                        # backup
git checkout -b dcp-v2 origin/feature/2678-did-document-service-identityhub-v2
```

### 4.3 What This Gives Us

The new `dcp-v2` branch starts with everything PR #8 has:
- DIM→DIV rename ✅ (from main)
- Identity extractor consolidation ✅ (from main)
- Federated catalog removal ✅ (from main)
- IH DidDocumentServiceClient v2 ✅ (from PR #8)
- DIV type-selector guard ✅ (from PR #8)
- Self-registration improvements ✅ (from PR #8)
- Helm chart IH templates ✅ (from PR #8)
- Migration guide + decision record ✅ (from PR #8)
- Deprecated API cleanup ✅ (bonus from PR #8)
- cx-policy refactoring ✅ (bonus from PR #8)

**Missing**: All of dcp's local deployment work → addressed in Phase 2.

---

## 5. Phase 2: Cherry-Pick 14 KEEP Commits

### 5.1 Commit Classification (17 dcp commits → 3 DROP + 14 KEEP)

| Commit | Message | Action | Reason |
|--------|---------|--------|--------|
| `722907f5d` | fix(dcp): resolve VP cache audience mismatch and credential ID extraction | **KEEP** ⚠️ | VP cache fix (real logic change). Conflict: `MembershipCredentialIdExtractionFunction.java` modify/delete → accept deletion |
| `eba32cae9` | feat(deployment): add local DCP deployment with per-company IdentityHub | **KEEP** | Core: Docker compose, configs, bootstrap, Dockerfile |
| `94cbbd7b4` | docs(deployment): add comprehensive DCP deployment documentation | **KEEP** | Docs: README, PRODUCTION_DEPLOYMENT_GUIDE |
| `73ffc3d65` | docs(deployment): add data transfer governance rationale and clarify PUSH terminology | **KEEP** | Docs |
| `4cd098c51` | fix(postman): add pre-request guards, fix connectorId, update PUSH terminology | **KEEP** | Postman |
| `f05b28b52` | fix(postman): add pre-request guards to suspend and terminate transfer | **KEEP** | Postman |
| `9eeb7d71f` | fix(postman): add pre-request guards to all requests with dynamic URL variables | **KEEP** | Postman |
| `088512a58` | feat(postman): add 31 missing endpoints for complete API coverage (65 requests, 16 folders) | **KEEP** | Postman |
| `20964b7e2` | docs(deployment): add API taxonomy — upstream EDC vs TX-customized vs TX-added endpoints | **KEEP** | Docs |
| `751dceda0` | docs(postman): explain why non-2xx responses are accepted in test assertions | **KEEP** | Docs |
| `639cc484e` | refactor(postman): make 5 endpoints return actual 2xx success responses | **KEEP** | Postman |
| `c45b126b8` | fix(infra): add DataService endpoints for connector discovery | **KEEP** | Deployment |
| `98ecf7dd4` | feat(did): add IdentityHub-based DidDocumentServiceClient (#2678) | **DROP** | IH v1 — replaced by PR #8 |
| `d8b2c8e30` | Merge branch 'feature/2678-did-document-service-identityhub' into dcp | **DROP** | Merge commit for v1 |
| `0882673c2` | fix: BDRS health check, DataService registration, docs accuracy | **KEEP** ⚠️ | Deployment fixes + VP cache. Conflict: same `MembershipCredentialIdExtractionFunction.java` → accept deletion |
| `c9135d1f2` | fix(did): review fixes for IdentityHub DidDocumentServiceClient (#2678) | **DROP** | v1 review fixes |
| `16bbe5a33` | fix: docs and Postman polling delays for local DCP deployment | **KEEP** | Docs/Postman |

### 5.2 Execution (Sequential Cherry-Pick)

```bash
cd /Users/wahidulazam/IdeaProjects/tractusx-edc
git checkout dcp-v2

# Commit 1: VP cache fix (has conflict)
git cherry-pick 722907f5d
# CONFLICT: MembershipCredentialIdExtractionFunction.java modify/delete
git rm edc-extensions/dataspace-protocol/dataspace-protocol-core/src/main/java/org/eclipse/tractusx/edc/protocol/core/identifier/MembershipCredentialIdExtractionFunction.java
git cherry-pick --continue

# Commits 2-12: All clean (deployment/docs/postman — no files exist on PR#8)
git cherry-pick eba32cae9  # local DCP deployment
git cherry-pick 94cbbd7b4  # deployment docs
git cherry-pick 73ffc3d65  # data transfer governance docs
git cherry-pick 4cd098c51  # postman pre-request guards
git cherry-pick f05b28b52  # postman suspend/terminate guards
git cherry-pick 9eeb7d71f  # postman dynamic URL guards
git cherry-pick 088512a58  # postman 31 missing endpoints
git cherry-pick 20964b7e2  # API taxonomy docs
git cherry-pick 751dceda0  # postman non-2xx docs
git cherry-pick 639cc484e  # postman 5 endpoints refactor
git cherry-pick c45b126b8  # DataService endpoints

# Commit 13: BDRS fix (has conflict — same file)
git cherry-pick 0882673c2
# CONFLICT: MembershipCredentialIdExtractionFunction.java modify/delete (again)
git rm edc-extensions/dataspace-protocol/dataspace-protocol-core/src/main/java/org/eclipse/tractusx/edc/protocol/core/identifier/MembershipCredentialIdExtractionFunction.java
git cherry-pick --continue

# Commit 14: Last one — clean
git cherry-pick 16bbe5a33  # docs and Postman polling delays
```

### 5.3 Expected Conflicts (Only 2)

| # | Commit | Conflicting File | Reason | Resolution |
|---|--------|-----------------|--------|------------|
| 1 | `722907f5d` | `MembershipCredentialIdExtractionFunction.java` | Deleted on PR#8 base (identity extractor consolidation), import-only change in dcp | `git rm <file>` — accept deletion. VP cache + `semicolon_delimited_script` changes apply cleanly. |
| 13 | `0882673c2` | `MembershipCredentialIdExtractionFunction.java` | Same file, same reason (import-reorder reversal) | `git rm <file>` — accept deletion. All deployment file changes apply cleanly. |

**Why no other conflicts?** All `deployment/local/*`, `docs/development/*`, and Postman files are **new paths** that don't exist on PR#8's base. Git creates them cleanly. The VP cache files exist on PR#8 but weren't modified by PR#8 (same as main) — so dcp's changes apply cleanly.

### 5.4 Identity Extractor Deletion Analysis

The deleted `MembershipCredentialIdExtractionFunction.java` was replaced by upstream `DefaultDcpParticipantIdExtractionFunction` (from `org.eclipse.edc:decentralized-claims-core:0.15.1`).

| Aspect | dcp: `MembershipCredentialIdExtractionFunction` | Upstream: `DefaultDcpParticipantIdExtractionFunction` |
|--------|------------------------------------------------|------------------------------------------------------|
| Claim key | `"vc"` | `CLAIMTOKEN_VC_KEY` (same `"vc"`) |
| Credential filter | Only MembershipCredential | Any VerifiableCredential |
| ID extraction | `CredentialSubject::getId` | `CredentialSubject::getId` |
| Error handling | Detailed `monitor.warning()` | Returns null on failure |
| Practical result | Same — all VCs in per-company IH share the same subject DID | Same |

**No logic lost by accepting deletion.**

---

## 6. Phase 3: Post-Cherry-Pick Fixes

### 6.1 DIM→DIV Rename in Local Deployment (5 files, ~8 occurrences)

These are the ONLY `dim`/`DIM` references remaining after cherry-pick. They're in dcp's local deployment files (which PR#8 never touched):

| File | Change | Line(s) |
|------|--------|---------|
| `deployment/local/config/provider-dp.properties` | `#tx.edc.iam.sts.dim.url` → `#tx.edc.iam.sts.div.url` | 35 (commented) |
| `deployment/local/config/consumer-dp.properties` | `#tx.edc.iam.sts.dim.url` → `#tx.edc.iam.sts.div.url` | 35 (commented) |
| `deployment/local/PRODUCTION_DEPLOYMENT_GUIDE.md` | `` `dim` `` → `` `div` ``, `client.type=dim` → `client.type=div`, `DIM wallet backends` → `DIV wallet backends`, `DIM-specific` → `DIV-specific`, `tx.edc.iam.sts.dim.url` → `tx.edc.iam.sts.div.url` | 456, 466 |
| `deployment/local/README.md` | `DIM integration` → `DIV integration` | 605 |
| `deployment/local/postman/EDC_Management_API_DCP.postman_collection.json` | `DIM integration` → `DIV integration` (inside JSON description) | (embedded) |

```bash
cd /Users/wahidulazam/IdeaProjects/tractusx-edc

# DP config comments
sed -i '' 's/tx.edc.iam.sts.dim.url/tx.edc.iam.sts.div.url/g' \
  deployment/local/config/consumer-dp.properties \
  deployment/local/config/provider-dp.properties

# Production deployment guide (all 5 dim patterns)
sed -i '' 's/tx.edc.iam.sts.dim.url/tx.edc.iam.sts.div.url/g' \
  deployment/local/PRODUCTION_DEPLOYMENT_GUIDE.md
sed -i '' 's/client.type=dim/client.type=div/g' \
  deployment/local/PRODUCTION_DEPLOYMENT_GUIDE.md
sed -i '' 's/DIM wallet backends/DIV wallet backends/g' \
  deployment/local/PRODUCTION_DEPLOYMENT_GUIDE.md
sed -i '' 's/DIM-specific/DIV-specific/g' \
  deployment/local/PRODUCTION_DEPLOYMENT_GUIDE.md
sed -i '' 's/or `dim`/or `div`/g' \
  deployment/local/PRODUCTION_DEPLOYMENT_GUIDE.md

# README.md
sed -i '' 's/DIM integration/DIV integration/g' \
  deployment/local/README.md

# Postman collection (JSON description field)
sed -i '' 's/DIM integration/DIV integration/g' \
  deployment/local/postman/EDC_Management_API_DCP.postman_collection.json

git add -A
git commit -m "fix: rename dim→div in local deployment configs and docs"
```

### 6.2 Comprehensive Post-Merge File Assessment

Every file brought in by the 14 KEEP commits was audited against PR#8's breaking changes
(DIM→DIV rename, identity extractor consolidation, federated catalog removal, deprecated API cleanup).

#### Docker Compose — NO CHANGES NEEDED

| Check | Result |
|-------|--------|
| Image names | `:local` tags — generic, no module references |
| DIM references | None |
| Federated catalog references | None |
| Port mappings | Unchanged — CP/DP/IH ports same as before |
| Volume mounts | Point to `./config/*.properties` — file contents change but compose itself doesn't |
| Network (`edc-net`) | External — unchanged |
| BDRS server config | Uses environment variables, no stale references |

#### Config Files — NO FUNCTIONAL CHANGES NEEDED

| File | Status | Details |
|------|--------|---------|
| `consumer-cp.properties` | ✅ Ready | `tx.edc.did.service.client.type=identityhub` correct for PR#8 IH extension; all `tx.edc.ih.*` properties match PR#8's `@Setting` annotations |
| `provider-cp.properties` | ✅ Ready | Same as consumer-cp — all IH properties correct |
| `consumer-dp.properties` | 🔵 Cosmetic | Line 35 `#tx.edc.iam.sts.dim.url` is commented out — rename to `div.url` for accuracy (not functional) |
| `provider-dp.properties` | 🔵 Cosmetic | Same as consumer-dp |
| `consumer-ih.properties` | ✅ Ready | IH-specific config, not affected by PR#8 EDC changes |
| `provider-ih.properties` | ✅ Ready | Same |
| `consumer-init.sql` | ✅ Ready | Database creation only (`CREATE DATABASE consumer_edc`) |
| `provider-init.sql` | ✅ Ready | Same |
| `ih-logging.properties` | ✅ Ready | JDK logging config, unaffected |

**Key property verification** (CP configs vs PR#8 IH extension requirements):
- `tx.edc.did.service.client.type=identityhub` → matches `CLIENT_TYPE_IDENTITYHUB` constant ✅
- `tx.edc.ih.identity.api.url=http://{company}-ih:15151/api/identity` → matches `@Setting(key="tx.edc.ih.identity.api.url")` ✅
- `tx.edc.ih.identity.api.key.alias={company}-ih-api-key` → matches `@Setting(key="tx.edc.ih.identity.api.key.alias")` ✅
- `tx.edc.ih.participant.context.id={company}` → matches `@Setting(key="tx.edc.ih.participant.context.id")` ✅
- `edc.participant.id=did:web:{company}-ih:{company}` → matches `@Setting(key="edc.participant.id")` for ownDid ✅
- Self-registration properties (`tx.edc.did.service.self.*`) → match self-registration extension on PR#8 ✅

**No new properties required**: PR#8's IH extension reads exactly the properties our configs already set.

#### Scripts — NO CHANGES NEEDED

| Script | API Versions Used | Stale References |
|--------|-------------------|------------------|
| `bootstrap.sh` | v3 Management API, v1alpha IH Identity API | None (no DIM, no FC, no deprecated paths) |
| `test-transfer.sh` | v3 Management API, `/v1/dsp` (DSP protocol — not deprecated) | None |
| `test-push-transfer.sh` | Same | None |
| `demo-management-api.sh` | Same | None |

#### Postman Collection — TEXT-ONLY FIX

| Check | Result |
|-------|--------|
| API paths | All 58+ endpoints use `/v3/` or `/v4alpha/` — zero deprecated `/v1/` or `/v2/` paths |
| Collection variables | 10 embedded variables (providerMgmt, consumerMgmt, etc.) — no external env file needed |
| FC references | None |
| DIM references | 1 occurrence: `DIM integration` in API taxonomy description → fix to `DIV integration` |

#### Documentation — TEXT-ONLY FIXES

| File | Stale References | Fix |
|------|-----------------|-----|
| `README.md` | Line 605: `DIM integration` | → `DIV integration` |
| `README.md` | Line 545: `edr-api-v2` replaces `edr-cache-api` | ✅ Still accurate — module still exists on PR#8 |
| `PRODUCTION_DEPLOYMENT_GUIDE.md` | Line 456: `dim` in table | → `div` |
| `PRODUCTION_DEPLOYMENT_GUIDE.md` | Line 466: 4 DIM patterns | → DIV (see §6.1 sed commands) |
| `local-dcp-issues-and-fixes.md` | None | ✅ No stale references |

#### Gradle Build — NO CHANGES NEEDED (inherited from PR#8)

| File | Why No Change Needed |
|------|---------------------|
| `edc-controlplane-base/build.gradle.kts` | PR#8 already includes `did-document-service-div` AND `did-document-service-identityhub` |
| `edc-controlplane-postgresql-hashicorp-vault/build.gradle.kts` | PR#8 already removed `federatedcatalog.feature.sql` |
| `settings.gradle.kts` | PR#8 already includes IH module |
| `gradle/libs.versions.toml` | PR#8 already adds IH-related version catalog entries |

None of these files are touched by KEEP commits — they stay as PR#8 set them.

#### Java Source — CHERRY-PICK CONFLICTS (handled in Phase 2)

| File | Issue | Resolution |
|------|-------|------------|
| `MembershipCredentialIdExtractionFunction.java` | Modified by KEEP commits `722907f5d` + `0882673c2`, but **DELETED** on PR#8 (identity extractor consolidation) | `git rm` during cherry-pick — the import reorder was cosmetic, no logic lost |
| VP cache files (3) | Modified by KEEP commits, unchanged on PR#8 | Clean cherry-pick — no conflict |

#### Summary

| Category | Files Needing Changes | Type of Change |
|----------|----------------------|----------------|
| Config (functional) | **0** | — |
| Config (cosmetic) | **2** DP properties | Comment `dim→div` |
| Docker Compose | **0** | — |
| Scripts | **0** | — |
| Documentation | **2** (README + PROD GUIDE) | Text `DIM→DIV` |
| Postman | **1** | Text `DIM→DIV` in description |
| Gradle/Build | **0** | — |
| **Total files needing post-merge edits** | **5** | All DIM→DIV text fixes (§6.1) |

---

## 7. Phase 4: Push IdentityHub Changes

### 7.1 Scope

The IH repo at `/Users/wahidulazam/IdeaProjects/tractusx-identityhub` has:

**9 unpushed commits**:
1. `251ffd8` — Copyright update (InitialParticipantExtension)
2. `cd2c6c3` — Copyright update
3. `23b1bae` — Deep review findings (API key logging, charset encoding)
4. `3ed1460` — Replace in-memory `ParticipantContextConfigStore` with upstream SQL store
5. `92dbd6f` — Add `participantcontextconfig` datasource config
6. `fe861e7` — Schema fix (`last_modified_date` nullable)
7. `a571664` — Merge from `feature/198-upgrade-edc-0.15.1`
8. `42c0c31` — Address reviewer feedback on SuperUserSeedExtension and copyrights
9. `19f26de` — Merge from `feature/198-upgrade-edc-0.15.1`

**5 uncommitted modified files**:
- `deployment/local/config/identityhub.properties`
- `deployment/local/config/issuerservice.properties`
- `docs/admin/EDC_0.15.1_UPGRADE_FIXES.md`
- `docs/api/API_CHANGES_AUDIT.md`
- `docs/developers/EDC_DCP_WALLET_INTEGRATION.md`

**1 untracked file**: `MERGE_PLAN.md`

### 7.2 Execution

```bash
cd /Users/wahidulazam/IdeaProjects/tractusx-identityhub

# Stage and commit uncommitted changes
git add deployment/local/config/identityhub.properties \
        deployment/local/config/issuerservice.properties \
        docs/admin/EDC_0.15.1_UPGRADE_FIXES.md \
        docs/api/API_CHANGES_AUDIT.md \
        docs/developers/EDC_DCP_WALLET_INTEGRATION.md
git commit -m "docs: update local deployment configs and documentation"

# Optionally add MERGE_PLAN.md
git add MERGE_PLAN.md
git commit -m "docs: add merge plan for ParticipantContextConfig store adoption"

# Push all
git push origin dcp-flow-local-deployment-with-upstream-0.15.1
```

### 7.3 Independence

IH changes are **completely independent** of EDC changes. The IH repo doesn't change any EDC APIs. The only coupling is:
- EDC connector configs reference IH container endpoints (e.g., `http://provider-ih:15151/api/identity`)
- These endpoint URLs haven't changed
- Can be done in parallel with Phases 1-3

---

## 8. Phase 5: Validation

### 8.1 Build Verification

```bash
cd /Users/wahidulazam/IdeaProjects/tractusx-edc
./gradlew clean build
```

**Expected**: Clean build with all tests passing. PR #8's 41 tests for the IH module should run. The deprecated API cleanup in PR #8 removed v1/v2 APIs — our deployment uses v3 Management API, so no impact.

### 8.2 Docker Image Build

The docker-compose uses pre-built images (`edc-controlplane:local`, `edc-dataplane:local`). Build them from the repo root:

```bash
cd /Users/wahidulazam/IdeaProjects/tractusx-edc

# Build controlplane image
docker build -t edc-controlplane:local \
  --build-arg JAR=edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/build/libs/edc-controlplane-postgresql-hashicorp-vault.jar \
  -f deployment/local/Dockerfile .

# Build dataplane image
docker build -t edc-dataplane:local \
  --build-arg JAR=edc-dataplane/edc-dataplane-hashicorp-vault/build/libs/edc-dataplane-hashicorp-vault.jar \
  -f deployment/local/Dockerfile .
```

### 8.3 Docker Deploy

```bash
cd deployment/local
docker compose down -v   # Wipe volumes — FC removal schema migration needs clean DB
docker compose up -d
```

### 8.4 Bootstrap & Test

```bash
bash scripts/bootstrap.sh
# Expected: 16/16 steps pass

bash scripts/test-transfer.sh
# Expected: E2E transfer completes (consumer-pull)

# Newman/Postman (collection has embedded variables — no environment file needed)
npx newman run postman/EDC_Management_API_DCP.postman_collection.json \
  --reporters cli
# Expected: 0 failures
```

### 8.5 Specific Validations

1. **Self-registration**: Verify DataService endpoint appears in DID document
   ```bash
   curl http://localhost:7100/provider/.well-known/did.json | jq '.service'
   ```
   Should show `DataService` entry

2. **IH Identity API**: Verify the connector calls IH identity API using PR #8's v2 client
   - Check CP logs for `DidDocumentServiceIdentityHubClient` messages
   - No errors about "client type not configured"

3. **Credential flow**: Verify VP/VC validation still works
   - Consumer should negotiate a contract with provider
   - Transfer should complete with valid EDR

4. **VP Cache**: Verify diagnostic logging from commit `722907f5d` works
   - Check CP logs for `areCredentialsValid` messages during negotiation

---

## 9. File-by-File Action Matrix

### Legend
- ⚪ **KEEP**: dcp-only file — cherry-picks cleanly (no file exists on PR#8 base)
- 🔵 **POST-FIX**: Needs manual edit after cherry-pick (Phase 3)
- 🟡 **CONFLICT**: Trivial modify/delete during cherry-pick — `git rm` to resolve
- 🟢 **AUTO**: Already correct on PR#8 base — no action needed

### 9.1 Files Created by Cherry-Pick (24 dcp-only files)

| File | Cherry-Pick Result | Post-Fix? |
|------|-------------------|-----------|
| `deployment/local/Dockerfile` | ⚪ Clean | — |
| `deployment/local/README.md` | ⚪ Clean | 🔵 `DIM integration→DIV integration` |
| `deployment/local/PRODUCTION_DEPLOYMENT_GUIDE.md` | ⚪ Clean | 🔵 `dim→div` (5 occurrences across 2 lines) |
| `deployment/local/docker-compose.yaml` | ⚪ Clean | — |
| `deployment/local/config/consumer-cp.properties` | ⚪ Clean | — |
| `deployment/local/config/consumer-dp.properties` | ⚪ Clean | 🔵 `dim→div` (1 comment) |
| `deployment/local/config/consumer-ih.properties` | ⚪ Clean | — |
| `deployment/local/config/consumer-init.sql` | ⚪ Clean | — |
| `deployment/local/config/ih-logging.properties` | ⚪ Clean | — |
| `deployment/local/config/provider-cp.properties` | ⚪ Clean | — |
| `deployment/local/config/provider-dp.properties` | ⚪ Clean | 🔵 `dim→div` (1 comment) |
| `deployment/local/config/provider-ih.properties` | ⚪ Clean | — |
| `deployment/local/config/provider-init.sql` | ⚪ Clean | — |
| `deployment/local/scripts/bootstrap.sh` | ⚪ Clean | — |
| `deployment/local/scripts/demo-management-api.sh` | ⚪ Clean | — |
| `deployment/local/scripts/test-push-transfer.sh` | ⚪ Clean | — |
| `deployment/local/scripts/test-transfer.sh` | ⚪ Clean | — |
| `deployment/local/postman/EDC_Management_API_DCP.postman_collection.json` | ⚪ Clean | 🔵 `DIM integration→DIV integration` (JSON desc) |
| `docs/development/local-dcp-issues-and-fixes.md` | ⚪ Clean | — |

### 9.2 Files with Cherry-Pick Conflicts or Notable Merges

| File | dcp Change | PR#8 State | Resolution |
|------|-----------|------------|------------|
| `MembershipCredentialIdExtractionFunction.java` | Import reorder (cosmetic) | **DELETED** | 🟡 CONFLICT: `git rm` — no logic lost |
| `semicolon_delimited_script` | Deleted by dcp | Exists (same blob) on PR#8 | 🟢 Auto-resolved: delete wins (same content → clean 3-way merge) |

### 9.3 Files Already Correct on PR#8 Base (No Action)

These files were only modified by the 3 DROP commits. Since we never cherry-pick those, they stay as PR#8 has them:

| File | Status |
|------|--------|
| `settings.gradle.kts` | 🟢 PR#8 already includes IH module |
| `edc-controlplane/edc-controlplane-base/build.gradle.kts` | 🟢 PR#8 has IH dep + FC removed |
| `edc-extensions/did-document/did-document-service-div/README.md` | 🟢 PR#8 has DIV version |
| `edc-extensions/did-document/did-document-service-div/.../DidDocumentServiceDivClientExtension.java` | 🟢 PR#8 has guard logic |
| `edc-extensions/did-document/did-document-service-identityhub/*` | 🟢 PR#8 v2 implementation |
| `edc-tests/e2e-fixtures/.../IatpParticipant.java` | 🟢 PR#8 has `client.type=div` + IH config |
| `edc-tests/e2e-fixtures/.../TractusxIatpParticipantBase.java` | 🟢 PR#8 has IH fields |
| `spi/did-document-service-spi/.../DidDocumentServiceClient.java` | 🟢 PR#8 has `TX_EDC_DID_SERVICE_CLIENT_TYPE` |
| `charts/tractusx-connector*/...` | 🟢 PR#8 has Helm templates |
| All DIM→DIV renames (classes, modules, tests) | 🟢 Already DIV on PR#8 base |
| Federated catalog removal | 🟢 Already removed on PR#8 base |
| Identity extractor → upstream | 🟢 Already `DefaultDcpParticipantIdExtractionFunction` on PR#8 |
| `CoreDataspaceProtocolExtension.java` | 🟢 Uses upstream function |
| `dataspace-protocol-core/build.gradle.kts` | 🟢 Has `decentralized-claims-core` dep |

### 9.4 VP Cache Files (Cherry-Pick Cleanly)

| File | dcp Change | PR#8 State | Result |
|------|-----------|------------|--------|
| `VerifiablePresentationCacheImpl.java` | Diagnostic logging (real change) | Same as main (unmodified) | ⚪ Clean cherry-pick |
| `CachePresentationRequestService.java` | Cosmetic (blank line) | Same as main (unmodified) | ⚪ Clean cherry-pick |
| `InMemoryVerifiablePresentationCacheStore.java` | Cosmetic (blank line) | Same as main (unmodified) | ⚪ Clean cherry-pick |

---

## 10. Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | Cherry-pick creates unexpected conflicts beyond the 2 known ones | Very Low | Medium | **MITIGATED**: Full simulation completed successfully. All 14 cherry-picks tested. |
| R2 | PR #8's deprecated API cleanup breaks Postman/test scripts | Low | Medium | Postman tests use Management API v3 (current); v1/v2 removed by PR #8 shouldn't affect local tests |
| R3 | FC removal breaks connector startup (missing migration) | Low | High | `docker compose down -v` wipes volumes for clean DB. Main adds drop-table migration. |
| R4 | VP cache diagnostic logging (`monitor.warning()`) noisy in production | Low | Low | Post-merge task: downgrade to `monitor.debug()`. Not a blocker. |
| R5 | IH repo unpushed changes conflict with upstream | Low | Low | IH changes are independent; push before or in parallel with EDC work |
| R6 | Commented `#tx.edc.iam.sts.dim.url` in DP configs causes confusion | Low | Low | Phase 3 renames to `div`. Configs are commented out anyway. |
| R7 | PostgreSQL database schema incompatible after FC removal | Medium | High | Plan includes `docker compose down -v` to wipe volumes |
| R8 | Upstream `DefaultDcpParticipantIdExtractionFunction` behavior differs in edge cases | Very Low | Low | Verified upstream source: gets subject ID from any VC. Functionally equivalent. |
| R9 | PR #8 branch gets more commits before we execute | Low | Low | Re-fetch and adjust. Cherry-picks are additive — new PR#8 commits won't affect our `deployment/local/` files. |
| R10 | `dcp-v2` diverges from future `main` updates | Low | Medium | After validation, consider merging PR#8 into main on GitHub and rebasing dcp-v2 onto new main. |

---

## 11. Rollback Strategy

### 11.1 Before Phase 1

```bash
# No destructive action — dcp-v2 is a new branch.
# Original dcp branch remains intact at 16bbe5a33.
# Nothing to back up.
```

### 11.2 If Cherry-Pick Fails Mid-Way

```bash
# Abort the in-progress cherry-pick
git cherry-pick --abort

# Option A: restart from scratch
git checkout dcp  # return to known-good branch
git branch -D dcp-v2
git checkout -b dcp-v2 origin/feature/2678-did-document-service-identityhub-v2

# Option B: inspect the conflict, resolve manually, then continue
git status  # see conflicting files
# ... resolve ...
git add <resolved-files>
git cherry-pick --continue
```

### 11.3 If Build Fails on dcp-v2

```bash
# dcp-v2 is the only branch affected; dcp is untouched
git checkout dcp
# Investigate build failure, fix on dcp-v2 when ready
```

### 11.4 If Deployment Fails After All Phases

```bash
# Return to known-good dcp deployment
cd deployment/local
docker compose down -v
git checkout dcp
./gradlew clean build
docker compose up -d
bash scripts/bootstrap.sh
```

### 11.5 Safe to Delete dcp-v2

Once `dcp-v2` is validated:
```bash
# Optionally rename dcp → dcp-v1-archive, dcp-v2 → dcp
git branch -m dcp dcp-v1-archive
git branch -m dcp-v2 dcp
```

---

## Appendix A: Cherry-Pick Simulation Log (2026-03-31)

**Branch**: `tmp-test-strategy` created from `origin/feature/2678-did-document-service-identityhub-v2` (`a10d58255`)

### Simulation Procedure

1. Created test branch: `git checkout -b tmp-test-strategy a10d58255`
2. Cherry-picked all 14 KEEP commits **sequentially** (order matters — later commits depend on files from earlier ones)
3. Recorded conflict/clean status for each commit
4. Cleaned up: `git checkout dcp && git branch -D tmp-test-strategy`

### Key Finding: Independent vs Sequential Testing

First attempt tested each cherry-pick independently (resetting HEAD after each). This produced **false-positive conflicts** because `deployment/local/` files don't exist on PR#8's tree — so commits that modify files created by earlier KEEP commits would fail when tested in isolation. Sequential testing (each cherry-pick building on the previous) proved the real conflict surface is only **2 trivial modify/delete** conflicts on a file that PR#8 already deleted.

### Results

| # | Commit | Result | Notes |
|---|--------|--------|-------|
| 1 | `722907f5d` | CONFLICT | `MembershipCredentialIdExtractionFunction.java` modify/delete → `git rm` |
| 2 | `eba32cae9` | CLEAN | Creates `deployment/local/` structure |
| 3 | `94cbbd7b4` | CLEAN | Deployment docs |
| 4 | `73ffc3d65` | CLEAN | Data transfer governance docs |
| 5 | `4cd098c51` | CLEAN | Postman pre-request guards |
| 6 | `f05b28b52` | CLEAN | Postman suspend/terminate guards |
| 7 | `9eeb7d71f` | CLEAN | Postman dynamic URL guards |
| 8 | `088512a58` | CLEAN | Postman 31 missing endpoints |
| 9 | `20964b7e2` | CLEAN | API taxonomy docs |
| 10 | `751dceda0` | CLEAN | Postman non-2xx docs |
| 11 | `639cc484e` | CLEAN | Postman 5 endpoints refactor |
| 12 | `c45b126b8` | CLEAN | DataService endpoints |
| 13 | `0882673c2` | CONFLICT | Same file modify/delete → `git rm`. VP cache auto-merged ✅ |
| 14 | `16bbe5a33` | CLEAN | Docs and Postman polling delays |

**Final state**: 14/14 applied. `deployment/local/` fully populated. VP cache preserved. Deleted files properly removed.

---

## Appendix B: Quick Reference Commands

```bash
# ── Phase 1: Create dcp-v2 ──
cd /Users/wahidulazam/IdeaProjects/tractusx-edc
git fetch origin
git checkout -b dcp-v2 origin/feature/2678-did-document-service-identityhub-v2

# ── Phase 2: Cherry-pick 14 commits ──
git cherry-pick 722907f5d   # → CONFLICT: git rm ...Function.java && git cherry-pick --continue
git cherry-pick eba32cae9 94cbbd7b4 73ffc3d65 4cd098c51 f05b28b52 9eeb7d71f 088512a58 20964b7e2 751dceda0 639cc484e c45b126b8
git cherry-pick 0882673c2   # → CONFLICT: git rm ...Function.java && git cherry-pick --continue
git cherry-pick 16bbe5a33

# ── Phase 3: Post-cherry-pick fixes (dim→div in 5 files) ──
sed -i '' 's/tx.edc.iam.sts.dim.url/tx.edc.iam.sts.div.url/' \
  deployment/local/config/consumer-dp.properties \
  deployment/local/config/provider-dp.properties
sed -i '' -e 's/tx.edc.iam.sts.dim.url/tx.edc.iam.sts.div.url/g' \
  -e 's/client.type=dim/client.type=div/g' \
  -e 's/DIM wallet backends/DIV wallet backends/g' \
  -e 's/DIM-specific/DIV-specific/g' \
  -e 's/or `dim`/or `div`/g' \
  deployment/local/PRODUCTION_DEPLOYMENT_GUIDE.md
sed -i '' 's/DIM integration/DIV integration/g' \
  deployment/local/README.md \
  deployment/local/postman/EDC_Management_API_DCP.postman_collection.json

# ── Phase 4: Push IH ──
cd /Users/wahidulazam/IdeaProjects/tractusx-identityhub
git add -A && git status
git commit -m "docs: finalize deployment configs"
git push origin dcp-flow-local-deployment-with-upstream-0.15.1

# ── Phase 5: Validate ──
cd /Users/wahidulazam/IdeaProjects/tractusx-edc
git checkout dcp-v2
./gradlew clean build
docker build -t edc-controlplane:local --build-arg JAR=edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/build/libs/edc-controlplane-postgresql-hashicorp-vault.jar -f deployment/local/Dockerfile .
docker build -t edc-dataplane:local --build-arg JAR=edc-dataplane/edc-dataplane-hashicorp-vault/build/libs/edc-dataplane-hashicorp-vault.jar -f deployment/local/Dockerfile .
cd deployment/local && docker compose down -v && docker compose up -d
bash scripts/bootstrap.sh && bash scripts/test-transfer.sh
```

---

## Appendix C: PR #8 Additional Changes (Outside IH Scope)

PR #8 also includes changes that are not related to the IH implementation but will be merged with it:

1. **Deprecated API cleanup (#2690)**: Removes `BusinessPartnerGroupApiV1`, `EdrCacheApiV2`, and related controllers/tests
2. **cx-policy refactoring**: Abstracts common logic into `AbstractDataEndDateConstraintFunction` and `AbstractDataEndDurationDaysConstraintFunction`
3. **Policy test improvements**: New `TestAgreementPolicyContext`, updated policy monitor/transfer tests

These are safe additions that don't conflict with dcp's local deployment work.

---

## Appendix D: Historical — v1 Plan Review Notes

v1 of this plan (dated 2026-03-30) used a rebase strategy: merge PR#8 into `main`, then interactive-rebase `dcp` onto the updated `main`, dropping 3 IH v1 commits.

v2 (this document) was born from the insight that PR#8 already incorporates `main`, so branching directly from PR#8 and cherry-picking the 14 deployment commits avoids all rebase complexity. A live simulation on `tmp-test-strategy` branch confirmed 14/14 cherry-picks succeed with only 2 trivial modify/delete conflicts.

The v1 plan identified 13 risks (R1–R13) and 7 post-rebase adjustment areas. The v2 strategy reduces this to 10 risks and 1 post-cherry-pick fix (DIM→DIV in 5 files).

Key v1 findings that remain valid in v2:
- `MembershipCredentialIdExtractionFunction.java` changes were import-only (cosmetic) → safe to accept deletion
- VP cache files are dcp-only modifications → cherry-pick cleanly
- Upstream `DefaultDcpParticipantIdExtractionFunction` is functionally equivalent to the deleted custom extractors
- PR#8's deprecated API cleanup (v1/v2 Management API removal) doesn't affect local deployment tests (Postman uses v3)
