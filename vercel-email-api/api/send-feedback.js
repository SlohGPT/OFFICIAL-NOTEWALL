/**
 * Vercel Serverless Function for NoteWall Feedback Emails
 * Using Resend API for reliable email delivery
 * 
 * Deploy: vercel
 * Set env var: RESEND_API_KEY=re_SMhC7U6f_Lew2A9Ku5w3VuMxZDtyx3u3i
 */

import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

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
    const { to, subject, body, reason, details, isPremium, timestamp, platform, appVersion, deviceModel, osVersion } = req.body;

    // Validate
    if (!to || !subject || !body) {
      return res.status(400).json({ error: 'Missing required fields: to, subject, body' });
    }

    // Convert plain text to HTML for better email formatting
    const htmlBody = body
      .replace(/\n/g, '<br>')
      .replace(/━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━/g, '<hr style="border: 1px solid #ddd; margin: 20px 0;">')
      .replace(/📋 REASON:/g, '<strong>📋 REASON:</strong>')
      .replace(/👤 USER TYPE:/g, '<strong>👤 USER TYPE:</strong>')
      .replace(/📅 TIMESTAMP:/g, '<strong>📅 TIMESTAMP:</strong>')
      .replace(/💬 ADDITIONAL DETAILS:/g, '<strong>💬 ADDITIONAL DETAILS:</strong>');

    // Add device info if available
    let deviceInfo = '';
    if (platform || appVersion || deviceModel || osVersion) {
      deviceInfo = `
        <hr style="border: 1px solid #ddd; margin: 20px 0;">
        <strong>📱 DEVICE INFO:</strong><br>
        ${platform ? `Platform: ${platform}<br>` : ''}
        ${appVersion ? `App Version: ${appVersion}<br>` : ''}
        ${deviceModel ? `Device: ${deviceModel}<br>` : ''}
        ${osVersion ? `OS: ${osVersion}<br>` : ''}
      `;
    }

    // Send email using Resend
    const data = await resend.emails.send({
      from: 'NoteWall Feedback <onboarding@resend.dev>',
      to: to,
      subject: subject,
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9; border-radius: 10px;">
          <div style="background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
            ${htmlBody}
            ${deviceInfo}
          </div>
          <div style="text-align: center; margin-top: 20px; color: #888; font-size: 12px;">
            Sent via NoteWall Feedback System
          </div>
        </div>
      `,
      text: body // Plain text fallback
    });

    console.log('✅ Email sent via Resend:', data.id);

    return res.status(200).json({
      success: true,
      messageId: data.id,
      message: 'Feedback email sent successfully via Resend'
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
