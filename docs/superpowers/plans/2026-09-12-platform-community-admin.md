# Platform Community Admin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementare admin globali nominati da Firebase con moderazione di tutte le community e proprietari invariati.

**Architecture:** Registro `platformAdmins/{uid}` read-only ai client; capability esplicite nella UI e nei servizi; Firestore come autorità finale. Moderazione dei contenuti tramite tombstone per conservare la progressione esistente.

**Tech Stack:** Flutter/Dart, Firebase Auth, Firestore, Node rules-unit-testing e Firebase Emulator.

**Spec:** docs/superpowers/specs/2026-09-12-platform-community-admin-design.md

## Global Constraints
- Ruolo globale solo per account collegati con `platformAdmins/{uid}.active == true`.
- Nessuna scrittura client al registro, nessuna estensione ai Gub privati.
- Conservare ownerId, ownership, membership/proiezioni e XP; accesso admin senza iscrizione automatica.
- UI inglese; commenti e documentazione italiana; nessuna infrastruttura a pagamento.

## Task 1: Ruolo admin e moderazione end-to-end

**Files:**
- Create: `lib/modules/community/admin/` per repository/servizio ruolo e schermate di amministrazione.
- Modify: `firestore.rules`, `lib/modules/community/services/`, `repositories/`, `models/`, `screens/`, `widgets/` limitatamente ai controlli e contenuti moderati; punto d'ingresso nella schermata account o My Gubs.
- Test: `tests/firestore-rules/platform-community-admin.test.mjs`; test Flutter del ruolo, del routing/admin entry e dei tombstone.
- Create: `docs/platform-community-admin.md` con istruzioni di attivazione/revoca e pubblicazione.

**Interfaces:** Registro autoritativo `platformAdmins/{uid}` con `active` booleano. La capability admin è distinta da isOwner/isMember. La lettura del ruolo deve seguire lo UID autenticato e revocarsi su errori/cambio account. I metodi di gestione membri devono continuare ad aggiornare tutte le proiezioni in transazione.

- [ ] Scrivere test emulator che falliscono per un admin non membro che legge/modera una community e test negativi per auto-promozione, anonimo, revoca e accesso a Gub privati. Eseguire contro le regole attuali per dimostrare il fallimento della feature.
- [ ] Implementare registro e capability; aggiungere i soli permessi di lettura/gestione necessari alle community. Testare che memberCount/ownership non possano essere alterati fuori dalle transazioni previste.
- [ ] Scrivere test Flutter comportamentali per admin entry/revoca e messaggi/Ask/Answer moderati. Collegare capability e azioni end-to-end senza assegnare artificialmente owner o member.
- [ ] Verificare rimozione/ban/unban/richieste per admin non membro. Aggiungere hide/unhide con payload ristretto e tombstone nei componenti reali; nessuna alterazione di XP o contenuti originali.
- [ ] Eseguire test nuovi e regressioni pertinenti, formatter/analyzer. Documentare limiti reali e comandi necessari per la pubblicazione; non dichiarare test passati se runtime indisponibile.
- [ ] Fare self-review, correggere problemi e commit solo dei file di questa feature. Restituire commit, test con output e criticità per revisione indipendente.

## Task 2: Verifica e consegna
- [ ] Revisione indipendente di sicurezza, conformità alla spec e qualità; risolvere regressioni concrete.
- [ ] Rieseguire le verifiche interessate dalle correzioni.
- [ ] Pubblicare un branch dedicato e una PR draft revisionabile. Nessun merge/deploy live.
