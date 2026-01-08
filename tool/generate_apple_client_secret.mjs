import { readFileSync } from 'node:fs';
import { createPrivateKey, createSign } from 'node:crypto';

function base64UrlEncode(input) {
  const buffer = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buffer
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const value = argv[i + 1];
    if (value == null || value.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = value;
      i += 1;
    }
  }
  return args;
}

function usage() {
  return [
    'Usage:',
    '  node tool/generate_apple_client_secret.mjs \\',
    '    --p8 /path/to/AuthKey_XXXXXXXXXX.p8 \\',
    '    --team-id YOUR_TEAM_ID \\',
    '    --key-id YOUR_KEY_ID \\',
    '    --client-id com.kurabe.app.service \\',
    '    --days 180',
    '',
    'Notes:',
    '  - Apple client secret (JWT) expiry max is 180 days.',
    '  - Do not commit the .p8 file; it should stay local.',
  ].join('\n');
}

const args = parseArgs(process.argv.slice(2));

const p8Path = args.p8 ?? process.env.APPLE_P8_PATH;
const teamId = args['team-id'] ?? process.env.APPLE_TEAM_ID;
const keyId = args['key-id'] ?? process.env.APPLE_KEY_ID;
const clientId = args['client-id'] ?? process.env.APPLE_CLIENT_ID;

const daysRaw = args.days ?? process.env.APPLE_SECRET_DAYS ?? '180';
const days = Math.max(1, Math.min(180, Number.parseInt(daysRaw, 10) || 180));

if (!p8Path || !teamId || !keyId || !clientId) {
  console.error(usage());
  process.exit(1);
}

const now = Math.floor(Date.now() / 1000);
const payload = {
  iss: teamId,
  iat: now,
  exp: now + days * 24 * 60 * 60,
  aud: 'https://appleid.apple.com',
  sub: clientId,
};

const header = {
  alg: 'ES256',
  kid: keyId,
};

const headerPart = base64UrlEncode(JSON.stringify(header));
const payloadPart = base64UrlEncode(JSON.stringify(payload));
const signingInput = `${headerPart}.${payloadPart}`;

const privateKeyPem = readFileSync(p8Path, 'utf8');
const privateKey = createPrivateKey(privateKeyPem);

const signer = createSign('SHA256');
signer.update(signingInput);
signer.end();

const signature = signer.sign({ key: privateKey, dsaEncoding: 'ieee-p1363' });
const signaturePart = base64UrlEncode(signature);

const jwt = `${signingInput}.${signaturePart}`;
process.stdout.write(jwt);
process.stdout.write('\n');
