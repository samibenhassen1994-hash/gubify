# Child Safety release gate — Gubify

This is a **release checklist**, not a statement of completed legal compliance.

## Product / engineering

- [x] In-app reason `child_safety_or_sexual_exploitation` on supported Community and private-Gub reports.
- [x] Admin reports inbox, status updates and report snapshots.
- [x] New branch: transactional append-only status events and history view.
- [x] New branch: dashboard warning for high-priority pending reports among the newest 100.
- [ ] Run Flutter analyzer and targeted widget tests on the new branch.
- [ ] Run Firebase emulator rule tests `npm run test:rules:platform-admin`, `npm run test:rules:all`.
- [ ] Reconcile deployment order of Firestore rules and client AAB; avoid temporarily breaking older admin clients.
- [ ] Review/report unsafe Community images: owner-only Cloudinary delete endpoint currently insufficient for platform admin; implement and verify backend permission separately, with safe unlink from public/root metadata.
- [ ] Provide and test genuine platform-level account restriction/suspension across Firestore, upload Worker, and alternate client paths (not merely Community ban).
- [ ] Verify user-generated content that might be cached/displayed by old app versions; hiding metadata does not physically remove it.
- [ ] Assess user-report mechanisms for Community images and all eligible image/profile metadata surfaces.
- [ ] Implement reliable out-of-app admin safety notification with secure rate-limiting, no case details in notification payload, and monitoring/failure reporting if coverage is required.

## Operations / legal

- [ ] Assign and privately record who monitors Child Safety safety@/legal@ contact.
- [ ] Confirm `legal@gubify.com` (or chosen published address) actually receives mail.
- [ ] Confirm https://gubify.com/guidelines returns a publicly accessible, functioning standards page (source contains explicit bans; live deployment not independently proven).
- [ ] Adopt and practise `docs/child-safety-escalation.md`; verify competent Italian and international authority reporting routes.
- [ ] Obtain advice on applicable DSA article 18 duties, privacy/retention, evidence preservation and escalation deadlines.
- [ ] Check Google Play Child Safety and broader UGC policy declarations against actual live controls.
- [ ] Verify no untested server rules or backend operations are deployed to production solely on this branch.
- [ ] Only then consider signing Play Console declarations, building a new AAB and planning rollout.

**Not done by this branch:** Cloudinary Worker changes, global account suspension, push/email alerts, legal compliance certification, deployment to Firebase, master merge, Google Play upload.
