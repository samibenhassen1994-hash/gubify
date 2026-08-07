import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: "Terms of Service",
      intro: "These Terms govern your use of the Gubify app, website and related services. They also set the rules for content, Gubs, Communities and participation in the Gubify beta.",
      versionLabel: "Terms version",
      version: "2026-08-07.2",
      lastUpdated: "August 7, 2026",
      icon: Icons.description_outlined,
      sections: [
        LegalSection(title: "1. Agreement and scope", blocks: [
          LegalBlock.paragraph("These Terms of Service (the Terms) apply when you access or use the Gubify mobile application, gubify.com and related pre-registration, beta, support and feedback services (together, the Service)."),
          LegalBlock.paragraph("By creating or using a Gubify identity, accepting these Terms in the app, or otherwise using a part of the Service that requires acceptance, you agree to these Terms. If you do not agree, do not use that part of the Service."),
          LegalBlock.paragraph("These Terms are separate from the Privacy Policy, which explains how Gubify processes personal data."),
        ]),
        LegalSection(title: "2. Service provider", blocks: [
          LegalBlock.address("Gubify — operated by Sami Ben Hassen\nPalmi (RC), Italy\nlegal@gubify.com"),
          LegalBlock.paragraph("Gubify is currently operated as a personal initiative rather than as an incorporated company. References in these Terms to “Gubify”, “we”, “us” or “our” mean the operator identified above."),
        ]),
        LegalSection(title: "3. Eligibility and accounts", blocks: [
          LegalBlock.paragraph("You must be at least 16 years old to create or use a Gubify account. Gubify is not intended for children under 16. If you are under the age of legal majority in your country, you may use Gubify only where permitted by applicable law and with any parental or guardian authorisation that may be required."),
          LegalBlock.paragraph("By creating or using a Gubify account, you represent that you meet these age and legal-capacity requirements. Gubify may restrict or terminate access where it reasonably determines that these requirements are not met."),
          LegalBlock.paragraph("You are responsible for the activity performed through your Gubify identity and for keeping access to your device and any linked account secure. Do not impersonate another person, create an identity for an unlawful purpose or attempt to access another user's identity."),
          LegalBlock.paragraph("During early versions of the app, Gubify may use anonymous Firebase authentication to create a technical user identity. Additional account or sign-in methods may be introduced later and may be subject to additional notices or security steps."),
        ]),
        LegalSection(title: "4. The Gubify service", blocks: [
          LegalBlock.paragraph("Gubify is designed to help groups and communities communicate, organise activities and coordinate shared information. Depending on the version available to you, features may include private Gubs, Communities, chat, Board posts, tasks, calendar and organised events, proposals, voting, Shared Budget, profiles, invitations and in-app notifications."),
          LegalBlock.paragraph("Gubify is operated from Italy and may be made available to users in multiple countries. Availability of the Service in a country does not mean that every feature is lawful or appropriate in every jurisdiction. You are responsible for using the Service in accordance with mandatory laws that apply to you. Gubify may limit or modify features in a particular country where reasonably necessary for legal, safety or operational reasons."),
          LegalBlock.paragraph("Features may be added, changed, limited or removed as Gubify evolves. Availability can differ between beta versions, devices, locations and accounts."),
        ]),
        LegalSection(title: "5. Your content", blocks: [
          LegalBlock.paragraph("You retain ownership of the text, information and other original material that you create and submit to Gubify (User Content). You are responsible for ensuring that you have the rights and permissions necessary to submit that content."),
          LegalBlock.paragraph("To operate the Service, you grant Gubify a non-exclusive, worldwide, royalty-free licence to host, store, reproduce, transmit, format and display your User Content only as reasonably necessary to provide, secure, maintain and improve the features you choose to use. This licence includes making content available to the users with whom you intentionally share it, such as members of a Gub or Community."),
          LegalBlock.paragraph("This licence ends when the relevant content is deleted from the Service, except to the extent that temporary backups, security records, legal obligations or content already lawfully shared with another user require limited continued processing."),
          LegalBlock.paragraph("Do not submit confidential, sensitive or personal information about another person unless you are authorised to share it and doing so is appropriate for the feature you are using."),
        ]),
        LegalSection(title: "6. Acceptable use and prohibited content", blocks: [
          LegalBlock.paragraph("Gubify contains user-generated content. You must use the Service in a lawful and respectful way. You may not use Gubify to create, upload, share, organise, promote or facilitate content or conduct that:"),
          LegalBlock.bullets([
            "is illegal or encourages, facilitates or instructs illegal activity;",
            "threatens, harasses, bullies, stalks or deliberately humiliates another person;",
            "promotes hatred, violence or discrimination against protected persons or groups;",
            "sexually exploits or endangers children, or includes child sexual abuse material;",
            "is pornographic or is primarily intended to facilitate sexual exploitation or sexual services;",
            "promotes suicide, self-harm or dangerous behaviour in a harmful manner;",
            "fraudulently impersonates another person or materially deceives users;",
            "violates another person's privacy, confidentiality, publicity or intellectual-property rights;",
            "contains malware, malicious code, phishing, credential theft or attempts to compromise accounts or devices;",
            "constitutes spam, automated abuse, manipulation of engagement or unwanted repetitive solicitation;",
            "attempts to bypass permissions, security rules, rate limits, membership controls or other safeguards;",
            "uses Gubify to sell, obtain or coordinate goods or services that are unlawful or prohibited by applicable platform rules.",
          ]),
          LegalBlock.paragraph("Context matters. Gubify may consider purpose, severity, risk, applicable law and platform requirements when assessing content or behaviour."),
        ]),
        LegalSection(title: "7. Gubs and Communities", blocks: [
          LegalBlock.paragraph("A private Gub is intended for its authorised members. A Community may expose limited public information for discovery while reserving member content for users who have joined according to the Community's access settings."),
          LegalBlock.paragraph("Owners and authorised roles may have additional controls over membership, access, content or the lifecycle of a Gub or Community. Users must not misrepresent their role, circumvent access requirements or attempt to gain membership without authorisation."),
          LegalBlock.paragraph("If you create or manage a Gub or Community, you are responsible for using administrative controls responsibly and for complying with these Terms when inviting, approving, managing or removing participants."),
        ]),
        LegalSection(title: "8. Moderation, reports and enforcement", blocks: [
          LegalBlock.paragraph("Gubify may review reports, investigate suspected abuse and take proportionate action to protect users, the Service and third parties. Depending on the circumstances, actions may include limiting access, removing or restricting content, revoking invitations, suspending a user or Community, preserving relevant records, or permanently terminating access."),
          LegalBlock.paragraph("Users may report suspected violations through the reporting or support mechanisms made available by Gubify. Serious safety, child-protection, security or legal concerns may be escalated where reasonably necessary or required by law."),
          LegalBlock.paragraph("Gubify does not guarantee that every item of User Content is reviewed before it becomes visible. The absence of immediate action does not mean that content or conduct is permitted under these Terms."),
        ]),
        LegalSection(title: "9. Shared Budget is not a payment service", blocks: [
          LegalBlock.paragraph("Shared Budget is an organisational feature for recording and coordinating information about a group's shared expenses, targets or contributions. Gubify does not hold, receive, transfer, settle or safeguard money on behalf of users and is not a bank, payment institution, electronic-money service, escrow service or financial adviser."),
          LegalBlock.paragraph("Amounts, balances, contribution records and similar information shown in Gubify are informational records entered or generated from user activity. Users remain responsible for verifying amounts and arranging any real-world payment independently."),
        ]),
        LegalSection(title: "10. Tasks, proposals, notes and events", blocks: [
          LegalBlock.paragraph("Tasks, assignments, proposals, votes, calendar entries and organised events are coordination tools. Unless the users involved separately create a legally binding agreement under applicable law, an action in Gubify does not by itself create an employment relationship, agency, partnership, fiduciary duty, financial obligation or other legal contract."),
          LegalBlock.paragraph("Users are responsible for checking practical details, permissions, costs, safety requirements and real-world arrangements connected with activities organised through Gubify."),
        ]),
        LegalSection(title: "11. Beta and pre-release services", blocks: [
          LegalBlock.paragraph("Beta or pre-release versions are provided for testing and may contain bugs, incomplete features, temporary limitations or changes that would not normally appear in a final release. Features, eligibility and beta capacity may change without guaranteeing continued access."),
          LegalBlock.paragraph("During testing, Gubify may need to migrate, reset or remove test data where reasonably necessary for development, security or reliability. Where a planned reset is material to users, Gubify will provide notice when reasonably practicable."),
          LegalBlock.paragraph("Pre-registration records interest in Gubify. It is not a purchase, reservation, guaranteed beta place, guaranteed release date or promise that a particular feature will be launched."),
        ]),
        LegalSection(title: "12. Feedback", blocks: [
          LegalBlock.paragraph("You may send bug reports, suggestions and other feedback to Gubify. You retain ownership of original material you submit. You grant Gubify permission to review, analyse, reproduce internally and use that feedback to evaluate, develop, secure or improve the Service."),
          LegalBlock.paragraph("Feedback does not create a right to compensation, attribution, exclusivity, implementation or an individual response."),
        ]),
        LegalSection(title: "13. Gubify intellectual property", blocks: [
          LegalBlock.paragraph("Gubify and its licensors retain all rights in the Gubify name, logos, branding, software, interface, original artwork, website design and other materials supplied by Gubify, excluding User Content."),
          LegalBlock.paragraph("Subject to these Terms, Gubify gives you a limited, personal, revocable, non-exclusive and non-transferable right to use the Service for its intended purpose. You may not copy, sell, sublicense, reverse engineer, scrape, exploit or create unauthorised derivative services from Gubify except where applicable law expressly permits it."),
        ]),
        LegalSection(title: "14. Third-party services", blocks: [
          LegalBlock.paragraph("Gubify relies on third-party infrastructure and platform services, including services provided by Google Firebase and Cloudflare. Your device, app store, operating system or other third-party services may also apply their own terms and privacy rules."),
          LegalBlock.paragraph("Gubify is not responsible for a third party's independent products, content or conduct. Nothing in these Terms limits any rights you have directly against a third party under applicable law."),
        ]),
        LegalSection(title: "15. Availability, maintenance and changes", blocks: [
          LegalBlock.paragraph("Gubify aims to provide a useful and reliable service but does not guarantee uninterrupted, error-free or permanent availability. The Service may be unavailable because of maintenance, testing, security incidents, provider outages, network conditions or circumstances outside reasonable control."),
          LegalBlock.paragraph("Gubify may modify, improve, replace or discontinue features where reasonably necessary. Where a material change significantly affects an established user feature, reasonable notice will be provided when appropriate and practicable."),
        ]),
        LegalSection(title: "16. Suspension, termination and deletion", blocks: [
          LegalBlock.paragraph("You may stop using Gubify at any time. Where deletion controls are available, you may use them to remove eligible content, Gubs or account data. You may also make a privacy or deletion request as described in the Privacy Policy."),
          LegalBlock.paragraph("Gubify may restrict, suspend or terminate access where reasonably necessary because of a serious or repeated breach of these Terms, illegal activity, security risk, abuse, harm to other users, legal requirements or actions necessary to protect the Service."),
          LegalBlock.paragraph("Where appropriate and legally required, Gubify will provide reasons or an opportunity to contact support. Immediate action may be taken where delay would create a material safety, security or legal risk."),
        ]),
        LegalSection(title: "17. Disclaimers", blocks: [
          LegalBlock.paragraph("Gubify is provided on an “as available” basis. To the extent permitted by applicable law, Gubify does not promise that every feature will be uninterrupted, free of defects, suitable for every purpose or preserved indefinitely."),
          LegalBlock.paragraph("User Content is created by users, not by Gubify. Gubify does not endorse or guarantee the accuracy, legality, reliability or completeness of User Content, proposals, votes, task details, events, Community information or Shared Budget records."),
          LegalBlock.paragraph("Nothing in these Terms excludes statutory guarantees, consumer rights or other protections that cannot lawfully be excluded or waived."),
        ]),
        LegalSection(title: "18. Limitation of liability", blocks: [
          LegalBlock.paragraph("To the maximum extent permitted by applicable law, Gubify is not liable for indirect, incidental or consequential losses that were not reasonably foreseeable when you agreed to these Terms, or for losses caused solely by another user, a third-party service, your device or circumstances outside Gubify's reasonable control."),
          LegalBlock.paragraph("Nothing in these Terms limits or excludes liability for fraud, wilful misconduct, gross negligence, death or personal injury where caused by negligence, or any other liability that applicable law does not permit to be limited or excluded."),
        ]),
        LegalSection(title: "19. Your responsibility", blocks: [
          LegalBlock.paragraph("You are responsible for your own User Content and conduct. If your use of Gubify unlawfully infringes another person's rights or causes a claim through your intentional or unlawful conduct, you remain responsible to the extent provided by applicable law."),
          LegalBlock.paragraph("This section does not require consumers to waive rights or accept liability beyond what applicable law allows."),
        ]),
        LegalSection(title: "20. Privacy", blocks: [
          LegalBlock.paragraph("Gubify's Privacy Policy explains what personal data are processed, the purposes and legal bases for processing, service providers, retention, deletion and privacy rights. The Privacy Policy forms an important part of the information provided to you when using Gubify but is separate from these Terms."),
        ]),
        LegalSection(title: "21. Changes to these Terms", blocks: [
          LegalBlock.paragraph("Gubify may update these Terms as the Service, legal requirements or safety needs change. The current version and effective update date will be published on this page."),
          LegalBlock.paragraph("If a change materially affects existing users, Gubify will provide additional notice or request renewed acceptance where reasonably appropriate or required by law. Continued use after a non-material update takes effect means the updated Terms apply to subsequent use."),
        ]),
        LegalSection(title: "22. Governing law and disputes", blocks: [
          LegalBlock.paragraph("Gubify is operated from Italy. These Terms are governed by Italian law, to the extent that such a choice is permitted. This choice of law does not deprive you of any mandatory consumer, contract, digital-service or other protection that you are entitled to under laws that cannot be excluded by agreement, including mandatory protections that may apply in the country where you habitually reside."),
          LegalBlock.paragraph("If you use Gubify as a consumer, any mandatory rules that give you the right to bring or defend proceedings before the courts of your country of residence remain unaffected. For disputes not governed by mandatory jurisdiction rules, the competent courts will be determined in accordance with applicable Italian and international private-law rules."),
          LegalBlock.paragraph("Before starting formal proceedings, you are encouraged to contact legal@gubify.com so that the issue can be understood and, where possible, resolved informally. This does not restrict any right to contact a competent authority, regulator, alternative dispute-resolution body or court where applicable."),
        ]),
        LegalSection(title: "23. General terms", blocks: [
          LegalBlock.paragraph("If a provision of these Terms is found unenforceable, the remaining provisions continue to apply to the extent permitted by law. A failure to enforce a provision immediately does not waive the right to enforce it later."),
          LegalBlock.paragraph("You may not transfer rights or obligations under these Terms in a way that would prejudice Gubify or other users without permission. Gubify may transfer operation of the Service and these Terms as part of a legitimate reorganisation, incorporation or transfer of the Gubify project, provided that users' mandatory rights are preserved and any required notice is given."),
        ]),
        LegalSection(title: "24. Contact", blocks: [
          LegalBlock.address("Legal: legal@gubify.com\nSupport: support@gubify.com\nPrivacy: privacy@gubify.com\nGeneral information: hello@gubify.com\nBeta: beta@gubify.com"),
        ]),
      ],
    );
  }
}
