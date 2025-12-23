/**
 * App Store Connect JWT Token Generator
 * 
 * Generates authentication tokens for App Store Connect API
 */

import jwt from 'jsonwebtoken';

/**
 * Generate JWT token for App Store Connect API
 * Tokens are valid for 20 minutes
 */
export async function generateToken() {
  const issuerId = process.env.ASC_ISSUER_ID;
  const keyId = process.env.ASC_KEY_ID;
  const privateKey = process.env.ASC_PRIVATE_KEY;
  
  if (!issuerId || !keyId || !privateKey) {
    throw new Error('Missing App Store Connect credentials. Required: ASC_ISSUER_ID, ASC_KEY_ID, ASC_PRIVATE_KEY');
  }
  
  // Clean up private key (remove extra escaping if present)
  const cleanPrivateKey = privateKey
    .replace(/\\n/g, '\n')
    .trim();
  
  // Ensure key has proper headers
  const formattedKey = cleanPrivateKey.includes('BEGIN PRIVATE KEY') 
    ? cleanPrivateKey 
    : `-----BEGIN PRIVATE KEY-----\n${cleanPrivateKey}\n-----END PRIVATE KEY-----`;
  
  try {
    const token = jwt.sign(
      {
        iss: issuerId,
        exp: Math.floor(Date.now() / 1000) + (20 * 60), // 20 minutes
        aud: 'appstoreconnect-v1'
      },
      formattedKey,
      {
        algorithm: 'ES256',
        header: {
          alg: 'ES256',
          kid: keyId,
          typ: 'JWT'
        }
      }
    );
    
    return token;
  } catch (error) {
    console.error('Error generating JWT token:', error);
    throw new Error(`Failed to generate JWT token: ${error.message}`);
  }
}

/**
 * Verify App Store Connect credentials are properly configured
 */
export function verifyCredentials() {
  const required = ['ASC_ISSUER_ID', 'ASC_KEY_ID', 'ASC_PRIVATE_KEY', 'ASC_APP_ID'];
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  
  return true;
}
