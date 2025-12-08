/**
 * Vercel Serverless Function for NoteWall Feedback Emails
 * 
 * Deploy: vercel
 * Set env vars: GMAIL_USER, GMAIL_APP_PASSWORD
 */

const nodemailer = require('nodemailer');

export default async function handler(req, res) {
  // CORS headers (allow requests from your app)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { to, subject, body, reason, details, isPremium, timestamp } = req.body;

    // Validate
    if (!to || !subject || !body) {
      return res.status(400).json({ error: 'Missing required fields: to, subject, body' });
    }

    // Create email transporter
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_APP_PASSWORD
      }
    });

    // Convert plain text to HTML
    const htmlBody = body
      .replace(/\n/g, '<br>')
      .replace(/━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━/g, '<hr>')
      .replace(/📋/g, '📋')
      .replace(/👤/g, '👤')
      .replace(/📅/g, '📅')
      .replace(/💬/g, '💬');

    // Send email
    const info = await transporter.sendMail({
      from: `"NoteWall Feedback" <${process.env.GMAIL_USER}>`,
      to: to,
      subject: subject,
      text: body,
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto;">
          ${htmlBody}
        </div>
      `
    });

    console.log('✅ Email sent:', info.messageId);

    return res.status(200).json({ 
      success: true, 
      messageId: info.messageId,
      message: 'Feedback email sent successfully' 
    });

  } catch (error) {
    console.error('❌ Error sending email:', error);
    return res.status(500).json({ 
      success: false,
      error: 'Failed to send email',
      details: error.message 
    });
  }
}

