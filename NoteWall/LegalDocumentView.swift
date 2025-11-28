import SwiftUI

struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if documentType == .privacyPolicy {
                        VStack(spacing: 20) {
                            Text("Privacy Policy")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            Text("Your Privacy Policy is hosted online.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text("Open Privacy Policy")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.appAccent)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                        }
                    } else if documentType == .termsOfService {
                        VStack(spacing: 20) {
                            Text("Terms of Use")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            Text("Your Terms of Use are hosted online.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                if let url = URL(string: "https://peat-appendix-c3c.notion.site/TERMS-OF-USE-2b7f6a63758f8067a318e16486b16f47?source=copy_link") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text("Open Terms of Use")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.appAccent)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                        }
                    } else if documentType == .termsAndPrivacy {
                        VStack(spacing: 20) {
                            Text("Legal Documents")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            // EULA Button
                            Button(action: {
                                if let url = URL(string: "https://peat-appendix-c3c.notion.site/END-USER-LICENSE-AGREEMENT-2b7f6a63758f80a58aebf0207e51f7fb?source=copy_link") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text("End-User License Agreement (EULA)")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.appAccent)
                                .cornerRadius(12)
                            }
                            
                            // Privacy Policy Button
                            Button(action: {
                                if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text("Privacy Policy")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.appAccent)
                                .cornerRadius(12)
                            }
                            
                            // Terms of Use Button
                            Button(action: {
                                if let url = URL(string: "https://peat-appendix-c3c.notion.site/TERMS-OF-USE-2b7f6a63758f8067a318e16486b16f47?source=copy_link") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text("Terms of Use")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.appAccent)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        Text(documentContent)
                            .font(.system(.body, design: .default))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // If privacy policy or terms of service, open URL immediately
            if documentType == .privacyPolicy {
                if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        UIApplication.shared.open(url)
                    }
                }
            } else if documentType == .termsOfService {
                if let url = URL(string: "https://peat-appendix-c3c.notion.site/TERMS-OF-USE-2b7f6a63758f8067a318e16486b16f47?source=copy_link") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
    
    private var documentContent: String {
        switch documentType {
        case .termsOfService:
            return "" // Handled in body - opens URL
        case .privacyPolicy:
            return "" // Handled in body - opens URL
        case .termsAndPrivacy:
            return termsAndPrivacyContent
        }
    }
}

// MARK: - Document Content

private let termsOfServiceContent = """
Terms of Service

Last Updated: November 13, 2024

1. Acceptance of Terms

By downloading, installing, or using NoteWall ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.

2. Description of Service

NoteWall is a mobile application that allows users to create personalized lock screen wallpapers with notes. The App integrates with Apple Shortcuts to apply wallpapers to your device.

3. Subscription and Payments

3.1 Free Trial
• New users receive a limited number of free wallpaper exports
• Premium subscriptions may include a free trial period (5-7 days)
• You will be charged at the end of the trial period unless you cancel before it ends

3.2 Subscription Plans
• NoteWall+ Lifetime: One-time payment for permanent access
• NoteWall+ Monthly: Monthly subscription with automatic renewal

3.3 Payment Processing
• All payments are processed through Apple's App Store
• Prices are displayed in your local currency
• Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period

3.4 Refunds
• Refund requests must be made through Apple's App Store
• We follow Apple's standard refund policy
• Contact Apple Support for refund assistance

4. User Obligations

You agree to:
• Use the App only for lawful purposes
• Not attempt to reverse engineer or modify the App
• Not use the App to create offensive or illegal content
• Comply with all applicable laws and regulations

5. Intellectual Property

5.1 App Ownership
• NoteWall and all related intellectual property rights belong to the developer
• You receive a limited, non-exclusive, non-transferable license to use the App

5.2 User Content
• You retain ownership of notes and photos you create or upload
• You grant us a license to process your content solely to provide the App's functionality
• We do not claim ownership of your personal content

6. Privacy and Data Protection

Your privacy is important to us. Please review our Privacy Policy for details on how we collect, use, and protect your data in compliance with GDPR and data protection laws.

7. Disclaimer of Warranties

THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.

8. Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES.

9. Changes to Terms

We reserve the right to modify these Terms at any time. Continued use of the App after changes constitutes acceptance of the modified Terms.

10. Termination

We may terminate or suspend your access to the App at any time, with or without cause or notice, for violation of these Terms.

11. Contact Information

For questions about these Terms, please contact:
• Email: support@notewall.app
• Developer: NoteWall Team

12. Severability

If any provision of these Terms is found to be unenforceable, the remaining provisions will continue in full force and effect.

13. Entire Agreement

These Terms, together with our Privacy Policy, constitute the entire agreement between you and NoteWall regarding the use of the App.
"""

private let privacyPolicyContent = """
Privacy Policy

Last Updated: November 13, 2024

1. Information We Collect

1.1 Personal Information
• Notes and Text: We store your notes locally on your device and do not transmit them to our servers
• Photos: Any photos you select for wallpaper backgrounds are processed locally on your device
• App Usage: We may collect anonymous usage statistics to improve the app

1.2 Automatically Collected Information
• Device Information: iOS version, device model (for compatibility)
• App Performance: Crash reports and performance metrics (anonymous)
• Purchase Information: Subscription status (processed by Apple)

2. How We Use Your Information

We use your information to:
• Provide the core wallpaper generation functionality
• Process in-app purchases through Apple's App Store
• Improve app performance and fix bugs
• Provide customer support

3. Data Storage and Security

3.1 Local Storage
• All your notes and photos are stored locally on your device
• We do not upload your personal content to external servers
• Your data remains private and under your control

3.2 Security Measures
• Data is protected by iOS security features
• No personal data is transmitted over the internet
• Purchase information is handled securely by Apple

4. Data Sharing

We do not sell, trade, or share your personal information with third parties, except:
• Apple: For processing in-app purchases
• Legal Requirements: If required by law or to protect our rights

5. Your Rights (GDPR Compliance)

As a user in the European Union, you have the right to:
• Access: Request information about data we process
• Rectification: Correct inaccurate personal data
• Erasure: Request deletion of your personal data
• Portability: Export your data in a readable format
• Objection: Object to processing of your personal data

6. Children's Privacy

NoteWall is not intended for children under 13. We do not knowingly collect personal information from children under 13.

7. Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app.

8. Contact Us

If you have questions about this Privacy Policy, please contact us:
• Email: support@notewall.app
• Developer: NoteWall Team

9. Data Retention

• Notes: Stored locally until you delete them
• App Settings: Stored locally until app is uninstalled
• Purchase Records: Maintained by Apple according to their policies

10. International Transfers

Since all data is processed locally on your device, there are no international data transfers.
"""

private let termsAndPrivacyContent = """
TERMS & PRIVACY

Last Updated: November 13, 2024

END-USER LICENSE AGREEMENT (EULA)

The End-User License Agreement (EULA) is hosted online. Please review the complete EULA using the link provided in the app interface.

SUBSCRIPTION TERMS

Auto-Renewable Subscriptions:
• Payment will be charged to your iTunes Account at confirmation of purchase
• Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period
• Account will be charged for renewal within 24-hours prior to the end of the current period
• You can manage and cancel your subscriptions by going to your Account Settings on the App Store after purchase
• Any unused portion of a free trial period will be forfeited when you purchase a subscription

Free Trial:
• New users receive 3 free wallpaper exports
• Premium subscriptions include a free trial period (5-7 days depending on plan)
• You will be charged at the end of the trial period unless you cancel before it ends

Refunds:
• All refund requests must be made through Apple's App Store
• Contact Apple Support for refund assistance

PRIVACY POLICY

Information We Collect:
• Notes and text you create (stored locally on your device only)
• Photos you select for wallpapers (processed locally on your device)
• Device information (iOS version, device model for compatibility)
• Anonymous app performance data to improve the app
• Purchase information (processed by Apple)

How We Use Information:
• Provide wallpaper generation functionality
• Process in-app purchases through Apple's App Store
• Improve app performance and fix bugs
• Provide customer support

Data Storage:
• All personal content (notes, photos) is stored locally on your device
• We do not upload your personal content to external servers
• Your data remains private and under your control
• Data is protected by iOS security features

Data Sharing:
• We do not sell, trade, or share your personal information
• Purchase information is shared with Apple for payment processing
• Anonymous crash reports may be shared through Apple's developer tools
• Information may be disclosed if required by law

Your Rights:
• EU residents have GDPR rights (access, rectification, erasure, portability)
• California residents have CCPA rights
• Contact support@notewall.app to exercise your rights

Children's Privacy:
• This app is not intended for children under 13
• We do not knowingly collect information from children under 13

Contact:
• Email: support@notewall.app
• Developer: NoteWall Team

Changes to Terms:
• We may update these terms and privacy policy
• Continued use constitutes acceptance of changes
• Check the "Last Updated" date for recent changes

This agreement is governed by applicable law and constitutes the entire agreement between you and NoteWall Team regarding use of this application.
"""

#Preview {
    LegalDocumentView(documentType: .privacyPolicy)
}
