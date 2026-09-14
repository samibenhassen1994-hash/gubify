# Moderazione globale delle community

La funzione è isolata nel branch `feature/platform-community-admin`, derivato da master. Non richiede Firebase Functions o servizi a pagamento. Non eseguire deploy per provare i test emulator.

## Attivazione e revoca

1. In Firebase Authentication individuare lo UID dell'account collegato Google/email. Un account anonimo non è idoneo.
2. In Firestore Console creare `platformAdmins/UID` con il solo campo booleano `active: true` (non la stringa `"true"`). L'operazione è riservata a chi amministra il progetto Firebase; non esiste auto-promozione nell'app.
3. Accedere con quell'account: in **Account** appare **Community moderation** dopo la conferma del ruolo dal server.
4. Revocare impostando `active: false` oppure eliminando il documento. Le regole negano le successive operazioni immediatamente. La UI rimuove contenuti e capability quando riceve revoca, errore o cambio account; dati del ruolo provenienti soltanto dalla cache non abilitano accesso.

I client possono leggere soltanto il proprio documento ruolo. Non possono elencare, creare, modificare o eliminare il registro, nemmeno se admin. Campi `role` nei profili o nelle membership non conferiscono questo potere.

## Utilizzo e limiti

L'area dedicata elenca tutte le community, incluse quelle non mostrate nell'Explorer e quelle con approvazione richiesta. Gli elenchi caricano inizialmente 50 documenti e **Load more** estende la finestra di altri 50. Le community in eliminazione sono visibili nell'elenco ma non apribili per moderazione.

L'admin può vedere membri, richieste, utenti bannati, chat e tutti gli Ask/Answer; approvare/rifiutare richieste, rimuovere/bannare/sbannare membri. L'ingresso non iscrive l'admin né mostra un composer. Il proprietario e l'attore non sono rimovibili/bannabili tramite i controlli di moderazione. Le operazioni strutturali (proprietà, eliminazione community, impostazioni) restano separate.

**Hide** e **Unhide** richiedono conferma e aggiornano soltanto `moderationHidden`, `moderatedBy`, `moderatedAt`. L'area amministrativa mostra ancora il testo originale per consentire la revisione; l'interfaccia ordinaria mostra **Removed by moderation** per messaggi, card Ask, riepiloghi Ask e Answer. Stato, Best Answer, relazioni, slot e XP non cambiano. Modificare un contenuto nascosto o convertirne un messaggio in Ask non è proposto dalla UI ordinaria.

Il tombstone è moderazione della visualizzazione, non redazione fisica o segretezza del dato. Le parole originali restano nel documento, e un client vecchio o personalizzato con permesso di lettura può leggerle. La build aggiornata è necessaria perché gli utenti vedano i tombstone; le vecchie versioni dell'app ignorano questi campi. La revoca non può cancellare copie già lette/esportate, né garantire la rimozione visiva istantanea su dispositivi disconnessi.

Rimozioni e ban riutilizzano la transazione esistente: membership, copia `users/UID/communities/ID`, contatori pubblici e proiezione `communityUserProgress` vengono aggiornati insieme senza cambiare XP. Per admin non proprietari, `membershipMutations/admin` contiene l'ultimo segnale transazionale (`action: remove`, UID bersaglio/attore, timestamp server). Non è un registro storico; le regole ne richiedono timestamp della richiesta e coerenza con tutte le proiezioni. Non conferisce permessi riutilizzabili.

Il ruolo non concede accesso ai Gub privati, ai documenti account privati, modifica degli autori o incrementi XP arbitrari. I profili personali non sono apribili dalla lista membri dell'area moderazione; le identità pubblicate nei contenuti/membership restano visibili.

## Verifica locale

Richiesti Node, Java 21 e Flutter compatibile con Dart 3.12.2 o successivo.

```sh
npm ci
npx firebase emulators:exec --only firestore --project demo-gubify 'npm run test:rules:platform-admin'
npx firebase emulators:exec --only firestore --project demo-gubify 'npm run test:rules:all'
flutter pub get
flutter test test/modules/community test/modules/profile/account_screen_test.dart
flutter analyze
```

I test emulator usano un progetto demo, non il database live. I risultati dell'implementazione e gli eventuali limiti del runtime sono nel report del task.

## Pubblicazione futura

Questo lavoro non esegue deploy, attivazione live, merge o caricamento Play Console. Dopo la revisione e l'approvazione del rilascio:

1. Eseguire i test e una prova manuale con account proprietario, membro e admin non membro; verificare revoca mentre è aperta una sottopagina di moderazione.
2. Pubblicare soltanto le regole sul progetto Firebase corretto con `firebase deploy --only firestore:rules --project ID_PROGETTO`.
3. Incrementare il numero dopo `+` in `pubspec.yaml` oltre il massimo versionCode già caricato su Play Console (il branch parte da `0.8.0+3`; verificare il valore effettivo in console).
4. Eseguire `flutter build appbundle --release` con firma release configurata e caricare l'AAB prima nel canale di test. Favorire l'aggiornamento degli utenti prima di affidarsi ai tombstone.
5. Attivare lo UID autorizzato dalla Console Firebase e verificare le operazioni con la nuova build. Per interrompere la moderazione revocare il ruolo; i tombstone esistenti restano fino a esplicito Unhide.
