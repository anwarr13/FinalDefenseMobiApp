import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // Replace these with your actual email credentials
  static const String _username = 'your_email@gmail.com';
  static const String _password = 'your_app_specific_password';

  final smtpServer = gmail(_username, _password);

  Future<void> sendApprovalEmail({
    required String recipientEmail,
    required String barName,
    required String ownerName,
  }) async {
    final message = Message()
      ..from = Address(_username, 'ShotSpot Admin')
      ..recipients.add(recipientEmail)
      ..subject = 'Bar Registration Approved! 🎉'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #2c3e50;">Congratulations, $ownerName! 🎉</h2>
          
          <p style="font-size: 16px; line-height: 1.5;">
            We're excited to inform you that your bar registration for <strong>$barName</strong> has been successfully approved!
          </p>

          <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="color: #2c3e50; margin-top: 0;">What's Next?</h3>
            <ul style="list-style-type: none; padding: 0;">
              <li style="margin: 10px 0;">✨ Log in to your account</li>
              <li style="margin: 10px 0;">📝 Complete your bar profile</li>
              <li style="margin: 10px 0;">🕒 Set your operating hours</li>
              <li style="margin: 10px 0;">📸 Add photos of your establishment</li>
              <li style="margin: 10px 0;">🎯 Highlight your special features</li>
            </ul>
          </div>

          <p style="font-size: 16px; line-height: 1.5;">
            Your bar is now visible to all ShotSpot users. Make sure to keep your information up to date to attract more customers!
          </p>

          <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="color: #2c3e50; margin-top: 0;">Need Help?</h3>
            <p style="margin-bottom: 0;">
              If you have any questions or need assistance, don't hesitate to contact our support team.
              We're here to help you make the most of your ShotSpot presence!
            </p>
          </div>

          <p style="font-size: 14px; color: #666; margin-top: 30px;">
            Best regards,<br>
            The ShotSpot Team
          </p>
        </div>
      ''';

    try {
      await send(message, smtpServer);
    } catch (e) {
      print('Error sending email: $e');
      throw Exception('Failed to send approval email');
    }
  }
}
