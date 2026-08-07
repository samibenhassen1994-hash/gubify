import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Privacy Policy',
      intro:
          'This policy explains what personal data Gubify processes when you use the Gubify app, website, pre-registration and feedback services, why those data are used, who may receive them and what choices you have.',
      versionLabel: 'Policy version',
      version: '2026-08-07.2',
      lastUpdated: 'August 7, 2026',
      icon: Icons.shield_outlined,
      sections: [
        LegalSection(
          title: '1. Scope and introduction',
          blocks: [
            LegalBlock.paragraph(
              'Gubify is a collaboration and community app designed to help people communicate, organise activities and coordinate shared information inside private Gubs and Communities. This Privacy Policy applies to the Gubify mobile application, gubify.com and the related pre-registration, support and feedback services operated by Gubify.',
            ),
            LegalBlock.paragraph(
              'Gubify is operated from Italy. The EU General Data Protection Regulation (GDPR) and applicable Italian data-protection law therefore provide the principal framework for the processing described in this policy. Where the law of another country also applies to particular users or processing and grants mandatory additional or different protections, Gubify will respect those protections to the extent required by applicable law.',
            ),
            LegalBlock.paragraph(
              'Personal data are processed according to applicable data-protection law and the principles of lawfulness, fairness, transparency, data minimisation, accuracy, storage limitation, integrity and confidentiality.',
            ),
          ],
        ),
        LegalSection(
          title: '2. Data controller',
          blocks: [
            LegalBlock.address(
              'Sami Ben Hassen\nPalmi (RC), Italy\nprivacy@gubify.com',
            ),
            LegalBlock.paragraph(
              'Gubify is currently managed as a personal initiative and not as a company. The person identified above is the data controller for the processing described in this policy, except where a service provider acts as an independent controller under its own terms and applicable law.',
            ),
          ],
        ),
        LegalSection(
          title: '3. Data processed in the Gubify app',
          blocks: [
            LegalBlock.paragraph(
              'The exact data processed depend on the features you use. The current version of the Gubify app may process the following categories.',
            ),
            LegalBlock.subheading('3.1 Account and profile data'),
            LegalBlock.bullets([
              'a Firebase Authentication user identifier;',
              'your chosen display name;',
              'account creation and update timestamps;',
              'profile information you choose to provide when a related feature is available.',
            ]),
            LegalBlock.paragraph(
              'At the date of this policy, the app initially authenticates users through Firebase anonymous authentication. Gubify does not currently require a phone number or password to create this initial app identity.',
            ),
            LegalBlock.subheading('3.2 Gub and Community information'),
            LegalBlock.bullets([
              'Gub and Community names, identifiers, descriptions and settings;',
              'membership, role and ownership information;',
              'join requests, invitation information and membership actions;',
              'Community type, language, access mode and member count;',
              'creation, update and other service timestamps.',
            ]),
            LegalBlock.subheading('3.3 Content and activity you create'),
            LegalBlock.paragraph(
              'Depending on the features you use, Gubify may store:',
            ),
            LegalBlock.bullets([
              'chat messages and message-related metadata;',
              'Board posts;',
              'tasks, assignments, status changes and completion information;',
              'calendar entries and organised events;',
              'proposals, votes and proposal status;',
              'Shared Budget information and member contribution information;',
              'in-app notifications and read/unread state;',
              'activity necessary to display your profile and participation inside a Gub.',
            ]),
            LegalBlock.paragraph(
              'Please do not include unnecessary sensitive personal data in messages, posts, tasks, events, proposals, budget descriptions or other free-text fields. Content you choose to submit is processed so that the relevant Gub or Community feature can work.',
            ),
          ],
        ),
        LegalSection(
          title: '4. Who can see app content',
          blocks: [
            LegalBlock.paragraph(
              'Gubify is a shared service. Some information you provide is therefore intentionally visible to other users as part of the feature you choose to use.',
            ),
            LegalBlock.bullets([
              'Content inside a private Gub is intended to be available only to users who are authorised members of that Gub, subject to their role and the permissions of the relevant feature.',
              'Public Community information, such as its name, description, type, language, access mode and member count, may be discoverable by other Gubify users through Community discovery features.',
              'Community chat content is intended for Community members according to the access rules applied by Gubify.',
              'Your display name and participation information may be shown to users who share a relevant Gub or Community with you.',
            ]),
            LegalBlock.paragraph(
              'Users should only share content with a Gub or Community when they are comfortable making that content available to the relevant members.',
            ),
          ],
        ),
        LegalSection(
          title: '5. Website and pre-registration data',
          blocks: [
            LegalBlock.paragraph(
              'When you pre-register for Gubify, the website may collect:',
            ),
            LegalBlock.bullets([
              'email address;',
              'first name, when voluntarily provided;',
              'device or platform interest;',
              'privacy consent, consent timestamp and accepted policy version;',
              'date and time of registration;',
              'UTM campaign parameters and landing page;',
              'security information necessary to protect the form from abuse.',
            ]),
            LegalBlock.paragraph(
              'Your first name is optional. The other information identified as required by the pre-registration form is necessary to complete that pre-registration.',
            ),
          ],
        ),
        LegalSection(
          title: '6. Feedback and diagnostic data',
          blocks: [
            LegalBlock.paragraph(
              'When you submit a bug report or feature suggestion, Gubify processes the information you provide in that submission. Depending on the report, this can include a title, description, reproduction steps, expected behaviour, usefulness information and an optional contact email.',
            ),
            LegalBlock.paragraph(
              'The feedback system may also process limited technical context useful for diagnosis, such as app version, platform, operating system, device model when available, browser name and version, language, timezone, viewport size, page URL, source page, report origin and site build identifier.',
            ),
            LegalBlock.paragraph(
              'A contact email supplied with feedback is used only where needed to clarify or follow up on that submission. Sending feedback does not automatically subscribe you to marketing or pre-registration.',
            ),
          ],
        ),
        LegalSection(
          title: '7. Technical and security data',
          blocks: [
            LegalBlock.paragraph(
              'Gubify and its infrastructure providers may process limited technical information needed to deliver, secure and maintain the service. This may include network, request, device, browser, authentication, security and anti-abuse information generated when the service is used.',
            ),
            LegalBlock.paragraph(
              'The website uses Cloudflare Turnstile to protect forms from automated abuse. Cloudflare may process technical information concerning the browser, device, network and interaction with the security check.',
            ),
            LegalBlock.paragraph(
              'At the date of this policy, the Gubify app does not use third-party advertising SDKs or behavioural advertising trackers.',
            ),
          ],
        ),
        LegalSection(
          title: '8. Purposes of processing',
          blocks: [
            LegalBlock.paragraph(
              'Gubify processes personal data where necessary to:',
            ),
            LegalBlock.bullets([
              'create and maintain your app identity and profile;',
              'provide private Gubs, Communities and their membership systems;',
              'deliver chat, tasks, events, proposals, Shared Budget, Board and notification features;',
              'display content to the users with whom it is intentionally shared;',
              'process invitations, join requests, ownership and membership actions;',
              'maintain read state and other feature state necessary for the app to work;',
              'record pre-registration and send communications directly connected to beta access or launch;',
              'receive, investigate and respond to feedback, support and bug reports;',
              'protect users and the service from spam, fraud, misuse, unauthorised access and other abuse;',
              'maintain, debug and improve reliability and security;',
              'respond to privacy requests and comply with applicable legal obligations.',
            ]),
            LegalBlock.paragraph(
              'Gubify does not sell personal data and does not disclose personal data to third parties for their independent behavioural advertising purposes.',
            ),
          ],
        ),
        LegalSection(
          title: '9. Legal bases',
          blocks: [
            LegalBlock.paragraph(
              'Where the General Data Protection Regulation (GDPR) applies, Gubify relies on one or more of the following legal bases, depending on the processing activity. Other privacy laws may use different legal concepts or requirements; where such laws apply, Gubify will process personal data on the basis required by those laws.',
            ),
            LegalBlock.bullets([
              'performance of a contract or steps requested by you, where processing is necessary to provide app features or a service you choose to use;',
              'consent, where Gubify specifically asks for it, including the current pre-registration launch communication;',
              'legitimate interests, including service security, fraud and abuse prevention, troubleshooting, support and responsible product improvement, where those interests are not overridden by your rights and freedoms;',
              'legal obligations, where processing is required by law.',
            ]),
            LegalBlock.paragraph(
              'Where processing is based on consent, you may withdraw that consent at any time. Withdrawal does not affect processing that was lawful before consent was withdrawn.',
            ),
          ],
        ),
        LegalSection(
          title: '10. Service providers and recipients',
          blocks: [
            LegalBlock.paragraph(
              'Gubify uses carefully selected infrastructure providers to operate the service. They may process personal data only to the extent necessary to provide their services, subject to their applicable terms and data protection obligations.',
            ),
            LegalBlock.bullets([
              'Google Firebase — Firebase Authentication is used for app authentication and Cloud Firestore is used to store and synchronise app data.',
              'Cloudflare — used for website hosting and delivery, Cloudflare Workers, Cloudflare D1, Cloudflare Turnstile, security and abuse prevention.',
            ]),
            LegalBlock.paragraph(
              'Personal data may also be disclosed where reasonably necessary to comply with law, enforce legal rights, protect users or the service, or respond to a valid request from a competent authority.',
            ),
          ],
        ),
        LegalSection(
          title: '11. International data transfers',
          blocks: [
            LegalBlock.paragraph(
              'Gubify is available internationally and some service providers operate distributed infrastructure outside the European Economic Area (EEA). In particular, Firebase Authentication may process data in the United States, while other Firebase and Cloudflare services may use global infrastructure. As a result, personal data may be processed in countries other than the country where you live.',
            ),
            LegalBlock.paragraph(
              'Where personal data are transferred from the EEA or from another jurisdiction that restricts international transfers, Gubify and its service providers must use a transfer mechanism or safeguard required by applicable law. Depending on the circumstances, this may include an adequacy decision, standard contractual clauses or another legally recognised safeguard.',
            ),
            LegalBlock.paragraph(
              'Laws in the destination country may differ from those in your country. This does not remove any transfer protections that applicable law requires Gubify to provide.',
            ),
          ],
        ),
        LegalSection(
          title: '12. Data security',
          blocks: [
            LegalBlock.paragraph(
              'Gubify uses technical and organisational measures designed to reduce the risk of unauthorised access, alteration, loss or disclosure. The current app uses Firebase Authentication together with Firestore Security Rules intended to restrict access according to authentication, membership and role.',
            ),
            LegalBlock.paragraph(
              'Infrastructure providers also apply their own security controls. No internet-connected service can guarantee absolute security, and users should avoid submitting information that is not necessary for the feature they are using.',
            ),
          ],
        ),
        LegalSection(
          title: '13. Data retention',
          blocks: [
            LegalBlock.paragraph(
              'Different categories of data are retained for different periods:',
            ),
            LegalBlock.bullets([
              'App account, profile and feature data are retained for as long as needed to provide the relevant service or feature, until they are deleted through an available deletion function or a valid deletion request, unless a longer period is required for legal, security or dispute-related reasons.',
              'Content shared with other users may remain available to the relevant Gub or Community until it, the relevant container or the associated account is deleted in accordance with the available product controls and applicable law.',
              'Pre-registration data are retained until launch and, after launch, ordinarily for no longer than 12 months, unless consent is withdrawn or deletion is requested earlier, or longer retention is required by law.',
              'Feedback reports and related diagnostic data are ordinarily retained for no longer than 24 months, unless longer retention is reasonably necessary for security, legal or dispute-related reasons.',
            ]),
            LegalBlock.paragraph(
              'When data are no longer needed for a legitimate purpose, Gubify will delete or anonymise them where reasonably possible and legally appropriate.',
            ),
          ],
        ),
        LegalSection(
          title: '14. Deletion and account requests',
          blocks: [
            LegalBlock.paragraph(
              'You may request deletion of personal data associated with you by contacting privacy@gubify.com. Gubify may need to verify that the request relates to you before acting on it.',
            ),
            LegalBlock.paragraph(
              'Pre-registration deletion is also available through the Gubify Support Center. Account-deletion controls will be made available for app accounts when account-based beta access is enabled.',
            ),
            LegalBlock.paragraph(
              'Gubify Support Center: https://gubify.com/support',
            ),
          ],
        ),
        LegalSection(
          title: '15. Your privacy rights',
          blocks: [
            LegalBlock.paragraph(
              'Your privacy rights depend on the law that applies to you and the circumstances of the processing. Under the GDPR, these may include the right to request:',
            ),
            LegalBlock.bullets([
              'access to personal data concerning you;',
              'rectification of inaccurate or incomplete data;',
              'erasure of personal data;',
              'restriction of processing;',
              'data portability, where applicable;',
              'objection to processing based on legitimate interests;',
              'withdrawal of consent where processing relies on consent.',
            ]),
            LegalBlock.paragraph(
              'If a privacy law outside the EEA applies to you and gives you additional mandatory rights — for example rights concerning access, correction, deletion, appeals or choices about certain uses or disclosures of personal data — those rights remain available to you to the extent required by that law. Gubify does not ask you to waive mandatory privacy rights through this policy or the Terms of Service.',
            ),
            LegalBlock.paragraph(
              'You may also have the right to lodge a complaint with the competent privacy or data-protection authority in your country. In Italy, the competent supervisory authority is the Garante per la protezione dei dati personali.',
            ),
            LegalBlock.paragraph(
              'To exercise a privacy right, contact privacy@gubify.com. Gubify may need to verify your identity before completing a request and will respond within the period required by the law that applies.',
            ),
          ],
        ),
        LegalSection(
          title: '16. Marketing and advertising',
          blocks: [
            LegalBlock.paragraph(
              'Pre-registration is used for communications directly connected to Gubify beta access or launch as described when you register. It does not automatically authorise unrelated marketing communications.',
            ),
            LegalBlock.paragraph(
              'At the date of this policy, Gubify does not sell personal data and the app does not use third-party behavioural advertising SDKs. If Gubify introduces optional marketing or materially different advertising practices in the future, this policy and any required choices will be updated first.',
            ),
          ],
        ),
        LegalSection(
          title: '17. Automated decision-making',
          blocks: [
            LegalBlock.paragraph(
              'Gubify does not currently use personal data to make decisions based solely on automated processing that produce legal effects or similarly significant effects concerning users.',
            ),
          ],
        ),
        LegalSection(
          title: '18. Children',
          blocks: [
            LegalBlock.paragraph(
              'Gubify is not intended for children under 16 years old. A person must be at least 16 to create or use a Gubify account. If a user is 16 or older but is still below the age of legal majority in their country, use of Gubify is permitted only where applicable law allows it and with any parental or guardian authorisation that may be required.',
            ),
            LegalBlock.paragraph(
              'Gubify does not intentionally seek to collect personal data from children under 16. If Gubify learns that an account belongs to a person under 16, it may restrict or delete the account and associated personal data as appropriate, subject to legal retention obligations and the rights of affected persons.',
            ),
            LegalBlock.paragraph(
              'If you believe personal data relating to a child under 16 have been processed through Gubify, contact privacy@gubify.com.',
            ),
          ],
        ),
        LegalSection(
          title: '19. Changes to this policy',
          blocks: [
            LegalBlock.paragraph(
              'Gubify may update this Privacy Policy as the app, website or legal requirements change. The current version will be published with an updated date and version number. Where a change materially affects users, Gubify will provide additional notice where required.',
            ),
          ],
        ),
        LegalSection(
          title: '20. Contact us',
          blocks: [
            LegalBlock.address(
              'Sami Ben Hassen\nPalmi (RC), Italy\nprivacy@gubify.com',
            ),
            LegalBlock.paragraph(
              'For privacy questions, requests or concerns, contact privacy@gubify.com.',
            ),
          ],
        ),
      ],
    );
  }
}
