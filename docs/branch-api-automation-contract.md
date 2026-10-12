# Branch API and Automation Contract v1.0
**Status:** design proposal, not a deployed API.

All branches use a common workflow contract. A backend must authenticate every request and authorize every action against the central role and branch membership records.

## Common job fields
- `job_id`: unique identifier
- `branch_key`: one of `ebook`, `audiobook`, `ai_video`, `youtube`, `social_media`
- `asset_id`: content item identifier
- `requested_by`: authenticated user identifier
- `status`: `draft`, `in_review`, `changes_requested`, `approved`, `scheduled`, `publishing`, `published`, `failed`
- `approved_by`, `approved_at`: required before a public publishing job runs
- `idempotency_key`: prevents duplicate publication on retries
- `created_at`, `updated_at`

## Actions
| Action | Minimum authority | Required checks |
|---|---|---|
| Create/edit draft | branch editor/producer or above | active user, membership in branch |
| Manage branch users | branch admin or main admin | branch scope; cannot grant main-admin role |
| Approve public release | main admin by default | asset and version match; record decision |
| Run approved publication | trusted automation service | approval valid, token available, idempotency key unused |
| Change central roles/policy | main admin only | MFA/reauthentication recommended; immutable audit event |
| View audit reports | main admin or assigned auditor | sensitive metadata minimized |

## Make.com webhook contract
A webhook must not accept a free-form instruction to publish arbitrary content. It should receive a signed, narrowly scoped job reference, verify signature and timestamp, retrieve the job from the trusted backend, confirm `approved` status, and then execute only the allowed connector action.

Required controls:
- Verify HMAC/signature and reject stale timestamps.
- Use idempotency keys and bounded retries.
- Store OAuth refresh tokens and API secrets only in a server-side secret store/managed connection.
- Record request ID, branch, action, outcome and platform response identifier; do not log tokens.
- Mark permanent errors as `failed` and surface them to the admin.
- Respect each platform's official API permissions and publishing rules.

## Single Sign-On (SSO)
The central identity provider authenticates the person once. Each branch validates the issued session/token and asks the backend for current branch permissions. Do not encode mutable role grants solely in client-side state. Revoking a membership must take effect server-side.

## Release checklist
- Unauthenticated access denied.
- Sub-admin cannot access other branches by changing an ID.
- Branch admin cannot grant central roles.
- Draft/rejected assets cannot be published by automation.
- Duplicate webhook delivery does not duplicate a public post.
- Token values never appear in browser code, Git history, or logs.
- Audit events exist for role changes, approvals, and publication attempts.
