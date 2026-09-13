# Admin globale per la moderazione delle community

## Obiettivo approvato
L'utente vuole poteri di moderazione mantenendo i creatori come proprietari. Ha scelto esplicitamente "Tutte le community": admin della piattaforma nominato esclusivamente da Firebase. Non cambiare ownerId, ruoli di membership o dati di proprietà.

## Autorità e limiti
- Registro separato `platformAdmins/{uid}` con booleano `active: true`, mantenuto dalla console Firebase/Admin SDK. Nessuna scrittura consentita ai client, nemmeno agli admin. Ogni utente autenticato può leggere soltanto il proprio documento; nessun elenco pubblico.
- Solo un account collegato (non anonimo) con quel documento attivo ha poteri admin. Revoca con active=false o eliminazione del documento. La UI deve reagire a cambio account/revoca ed errori chiudendo i permessi; Firestore è sempre autoritativo.
- Il ruolo riguarda tutte le COMMUNITY, anche quando l'admin non è membro. Non attribuisce accesso ai Gub privati, a credenziali o ad altri documenti privati degli utenti.
- L'admin può visualizzare community, membri, richieste, chat e Ask/Answer; approvare/rifiutare richieste; rimuovere, bannare e sbannare membri non proprietari. Proteggere owner e attore dalle rimozioni; non consentire cambio proprietà, nomina di altri admin, cancellazione community, XP arbitrari, cambi identità o modifica delle parole altrui.
- L'admin può moderare contenuti nascondendo testo di messaggi, Ask e Answer con campi di moderazione separati. Preferire tombstone visuale "Removed by moderation" per mantenere relazioni, contatori, slot attivi e ricompense. Non cancellare o alterare una Best Answer come scorciatoia.
- Entrare per moderare non crea membership, non incrementa memberCount e non permette di pubblicare messaggi/Ask/Answer senza i normali requisiti di membership.

## Integrazione
Estendere i controlli delle azioni di moderazione con capability esplicite, senza falsificare isOwner/isMember. Mantenere le operazioni strutturali del proprietario separate. Usare un servizio/repository dedicato al ruolo globale, seguendo lo stile esistente e aggiungendo injection soltanto ai confini utili ai test.

Prevedere un ingresso raggiungibile nell'app per l'admin ("Community moderation") che consenta di accedere alle community anche con approvazione richiesta o nascoste dall'Explorer pubblico. Riutilizzare le schermate esistenti dove possibile. Le azioni devono avere conferma e mostrare errori/risultato. Le normali schermate dei membri devono mostrare il tombstone per tutti i contenuti moderati.

## Sicurezza dei dati
Usare controlli stretti sulle chiavi modificabili. I permessi aggiuntivi non devono permettere di modificare ownerId, memberCount senza le proiezioni coerenti, XP, testo originale, autori o documenti utenti. Mantenere le transazioni di rimozione/proiezione. Verificare emulator con utente normale, anonimo, admin attivo, admin revocato e admin non membro; la modifica di users/{uid}.role o members/{uid}.role non deve conferire autorità.

## Consegna
Branch separato `feature/platform-community-admin`, test di sicurezza ed app, documentazione italiana per deploy regole, attivazione tramite UID Firebase, revoca e build AAB con versionCode incrementato quando l'utente pubblicherà. Nessun deploy regole o assegnazione ruolo live durante l'implementazione. UI inglese, commenti/documentazione italiana. Nessuna dipendenza a pagamento o Firebase Functions.
