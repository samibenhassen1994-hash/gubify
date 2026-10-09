# Child Safety: internal review and escalation procedure

**Owner:** Gubify Child Safety lead (designate a named responsible person privately).
**Status:** Draft operating procedure — must be reviewed, adopted, and followed before attesting compliance.
**Scope:** Private Gubs, public Communities, user profiles, Community images and other user-generated content.

## Purpose and trigger

Gubify prohibits CSAM/CSEA, grooming, sexual solicitation of minors, and attempts to solicit or distribute abusive material. A platform rule applies even if messaging is text-only: chat can contain grooming, threats, requests, links or attempts to move communication off-platform. Community images are a separate media-upload surface.

Treat an in-app Child Safety report, an email sent to the designated safety contact, or information received from a trusted external authority as a safety signal. A report is **not** proof of wrongdoing.

## Triage

1. **Immediate danger:** If there is a credible imminent threat to a child's safety, contact the appropriate emergency service immediately (112 in Italy). Do not wait for internal confirmation or completion of review.
2. **High-risk suspicion:** Promptly review the report metadata and the narrow content snapshot already supplied. Prioritise grooming, solicitation of minors, coercion, threats, and suspected CSAM. Under EU Digital Services Act article 18, hosting services in scope may have a duty to inform law enforcement/judicial authorities promptly of information creating a suspicion of a criminal offence involving a threat to the life or safety of persons. This is not limited to confirmed CSAM.
3. **Clearly unfounded:** Record the rationale, close the report, and allow correction/reopening where new evidence emerges. Do not categorise a report as false merely because the reported content is no longer accessible.
4. **Actionable:** Restrict visibility/access where the verified product controls allow it; for serious or repeated violations seek effective account-wide and original-media enforcement through trusted backend administrators. **Hiding a text widget or marking a report `action_taken` is not deletion of original data or a global account suspension.**

## Authority notification

Use an **official, verified channel** determined for the case, jurisdiction and actual legal obligations. For Italy, the Polizia Postale / Centro Nazionale per il Contrasto alla Pedopornografia Online (CNCPO) is a relevant competent authority. NCMEC CyberTipline is another channel for reports of online child sexual exploitation, subject to applicable legal/reporting rules. Confirm the correct channel and any statutory reporting deadlines with qualified counsel.

Provide only lawfully relevant data via an appropriate secure official channel: report ID, account/content IDs, timestamps, factual description, enforcement action, and a callback contact. Avoid conjecture. **Never download, duplicate, forward, screenshot, or redistribute suspected CSAM** for internal record-keeping. Seek authority direction on lawful preservation and transfer of original material where necessary.

Do not contact the suspected offender to warn them of a pending law-enforcement report. Do not attempt undercover investigation, entrapment or personal contact with an alleged child victim. Cooperate with legitimate preservation and legal requests while respecting privacy and security requirements.

In the admin report record note: whether a competent authority was contacted, date/time, which official channel, external reference if one exists, and enforcement taken, without storing illegal imagery or unnecessary personal data. The `escalated` status is **only an internal workflow label** and is not proof that a report was sent.

## Evidence, access and safeguards

- Limit access to specifically authorised platform administrators, using the pre-existing `platformAdmins/{uid}` registry.
- Preserve the report snapshot and IDs as permitted by law. Avoid broad browsing of private communications or copying reported material elsewhere.
- The append-only client audit events record only **changes of report status**, author, time, and a short action note. Database/project administrators can still change server-side data. This is not a forensic evidence vault.
- Do not put child-identifying or illegal content in status notes. Define and implement appropriate retention, access, deletion, breach-response and lawful-hold practices with privacy counsel.
- Review any moderation action/appeal through `legal@gubify.com` or `support@gubify.com` when the contact is verified operational.
- Keep the safety response process available even when the admin cannot open the app; relying only on the in-app dashboard is insufficient for urgent alerts.

## Current technical limitations and prerequisite work

- Chat messages are text-only; Community images exist via Cloudinary and a separate media Worker.
- Community text `moderationHidden` masks content in compatible clients, **not** original Firestore text. Existing old clients may still display it.
- The Community image delete Worker currently authorises the Community owner. A platform-admin remove-image button is **not available** until the Worker server-side authorisation and Cloudinary deletion flow are updated and security-tested.
- Per-Community bans are not a platform-wide account suspension. Account-wide enforcement must be implemented and verified across every Firestore and media API path before relying on it.
- Admin safety queue provides in-app visibility, not external notifications or 24/7 coverage.

Do **not** mark the Google Play declaration fully compliant based on this document alone. Adopt the procedure, verify official contacts and obligations, test real enforcement, confirm public standards are live and accessible, and perform privacy/legal review.

## External sources to verify during operational approval

- Google Play: Child Safety Standards policy for Social/Dating apps: https://support.google.com/googleplay/android-developer/answer/14747720
- EU Digital Services Act, Regulation (EU) 2022/2065, article 18: https://eur-lex.europa.eu/eli/reg/2022/2065/oj
- Italian Polizia Postale: https://www.commissariatodips.it/
- NCMEC CyberTipline: https://report.cybertip.org/

**Maintenance:** review this procedure when products, reporting laws, or Google Play policies change.
