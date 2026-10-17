import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'
import { inflateRawSync } from 'node:zlib'
import { fileURLToPath } from 'node:url'

// Read-only scan. Report locations and rule names, never credential values.
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const expectedRef = 'mqnnzobfzbtolvmatuwr'
const roots = process.argv.slice(2)
if (!roots.length) throw new Error('Supply source, bundle, or release paths to scan')
const findings = []
const reviewedNonSecrets = []
const knownPrivate = new Set()
const publicValues = new Set()
let files = 0
let archiveEntries = 0
let productionProjectSeen = false

function walk(location, visit) {
  for (const entry of fs.readdirSync(location, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) throw new Error(`Symlink is not allowed: ${location}`)
    const child = path.join(location, entry.name)
    if (entry.isDirectory()) walk(child, visit)
    else if (entry.isFile()) visit(child)
  }
}

function envPairs(file) {
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).flatMap(line => {
    const match = line.match(/^\s*(?:export\s+)?([A-Z][A-Z0-9_]*)\s*=\s*(.*?)\s*$/)
    return match ? [[match[1], match[2].replace(/^(['"])(.*)\1$/, '$2')]] : []
  })
}

for (const app of ['customer_app', 'rescuer_app']) {
  const config = JSON.parse(fs.readFileSync(path.join(repo, 'frontend', app, 'config/supabase.dev.json')))
  if (Object.keys(config).sort().join(',') !== 'SUPABASE_PUBLISHABLE_KEY,SUPABASE_URL' ||
      config.SUPABASE_URL !== `https://${expectedRef}.supabase.co` ||
      !/^sb_publishable_[A-Za-z0-9_-]+$/.test(config.SUPABASE_PUBLISHABLE_KEY)) {
    throw new Error(`${app}: production configuration failed (values withheld)`)
  }
  Object.values(config).forEach(value => publicValues.add(value))
}

// Compare against local private credentials without copying them into a report.
for (const directory of ['.', 'admin_web', 'backend', 'backend/supabase']) {
  const base = path.join(repo, directory)
  for (const name of fs.readdirSync(base)) {
    if (!/^\.env(?:\..+)?$/.test(name) || name.endsWith('.example')) continue
    const file = path.join(base, name)
    if (!fs.statSync(file).isFile()) continue
    for (const [key, value] of envPairs(file)) {
      if (publicValues.has(value)) continue
      if (value.length >= 16 && /SECRET|PASSWORD|TOKEN|API_KEY|SERVICE_ROLE|DATABASE_URL|DB_URL|DSN|PRIVATE_KEY|ACCESS_KEY/.test(key)) {
        knownPrivate.add(value)
      }
    }
  }
}

function record(location, rule) { findings.push({ location, rule }) }

function inspect(bytes, location) {
  // latin1 preserves every byte, including ASCII strings embedded in AOT binaries.
  const text = bytes.toString('latin1')
  // Tika ships MIME magic signatures, not private key material. Exempt only
  // these exact reviewed XML tags; scan all remaining bytes of this resource.
  const credentialText = /!(?:base\/root\/)?org\/apache\/tika\/mime\/tika-mimetypes\.xml$/.test(location)
    ? text.replace(/<match value="-----BEGIN (?:RSA |DSA )?PRIVATE KEY-----" type="string" offset="0"\/>/g, () => {
      reviewedNonSecrets.push({ location, rule: 'tika-mime-magic-signature' })
      return ''
    })
    : text
  if (text.includes(`${expectedRef}.supabase.co`)) productionProjectSeen = true
  for (const value of knownPrivate) {
    if (text.includes(value) || text.includes(Buffer.from(value).toString('base64'))) {
      record(location, 'known-local-private-credential')
    }
  }
  for (const [rule, pattern] of [
    ['supabase-secret-key', /sb_secret_[A-Za-z0-9_-]{16,}/],
    ['private-key', /-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----/],
    ['aws-access-key', /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/],
    ['github-token', /\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b/],
    ['postgres-credential-url', /postgres(?:ql)?:\/\/[^\s:"'<>]+:[^\s@"'<>]+@/],
  ]) if (pattern.test(rule === 'private-key' ? credentialText : text)) record(location, rule)
  for (const match of text.matchAll(/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g)) {
    try {
      const payload = JSON.parse(Buffer.from(match[0].split('.')[1], 'base64url').toString('utf8'))
      if (payload.role === 'service_role') record(location, 'service-role-jwt')
      if (payload.role === 'anon' && payload.ref !== expectedRef) record(location, 'wrong-project-anon-jwt')
    } catch { /* Only valid JWT payloads are classified. */ }
  }
  if (/config\/|admin_web[\\/]dist|\.(?:apk|zip)!/.test(location)) {
    if (text.includes('sepay_test')) record(location, 'test-sepay-scope')
    if (text.includes('https://admin-test.supabase.co')) record(location, 'test-supabase-endpoint')
    for (const match of text.matchAll(/https:\/\/([a-z0-9]{20})\.supabase\.co/g)) {
      if (match[1] !== expectedRef) record(location, 'unexpected-supabase-project')
    }
  }
}

function archive(bytes, location) {
  let end = -1
  for (let i = bytes.length - 22; i >= Math.max(0, bytes.length - 65557); i--) {
    if (bytes.readUInt32LE(i) === 0x06054b50 && i + 22 + bytes.readUInt16LE(i + 20) === bytes.length) { end = i; break }
  }
  if (end < 0) throw new Error(`Invalid ZIP: ${location}`)
  const count = bytes.readUInt16LE(end + 10)
  if (count === 0xffff) throw new Error(`ZIP64 requires another scanner: ${location}`)
  let cursor = bytes.readUInt32LE(end + 16)
  for (let i = 0; i < count; i++) {
    if (bytes.readUInt32LE(cursor) !== 0x02014b50) throw new Error(`Bad central directory: ${location}`)
    const flags = bytes.readUInt16LE(cursor + 8)
    const compression = bytes.readUInt16LE(cursor + 10)
    const compressed = bytes.readUInt32LE(cursor + 20)
    const size = bytes.readUInt32LE(cursor + 24)
    const nameLength = bytes.readUInt16LE(cursor + 28)
    const extraLength = bytes.readUInt16LE(cursor + 30)
    const commentLength = bytes.readUInt16LE(cursor + 32)
    const local = bytes.readUInt32LE(cursor + 42)
    const name = bytes.subarray(cursor + 46, cursor + 46 + nameLength).toString('utf8')
    cursor += 46 + nameLength + extraLength + commentLength
    if (name.endsWith('/')) continue
    if (flags & 1) throw new Error(`Encrypted entry cannot be scanned: ${location}`)
    if (/(^|\/)(?:\.env(?:\..*)?|key\.properties|STITCH_DESIGN_REPORT[^/]*|\.payment-sevqr-work)(?:\/|$)|\.(?:jks|keystore)$/i.test(name)) {
      record(`${location}!${name}`, 'forbidden-packaged-file')
    }
    if (bytes.readUInt32LE(local) !== 0x04034b50) throw new Error(`Bad local ZIP header: ${location}`)
    const start = local + 30 + bytes.readUInt16LE(local + 26) + bytes.readUInt16LE(local + 28)
    const data = bytes.subarray(start, start + compressed)
    const unpacked = compression === 0 ? data : compression === 8 ? inflateRawSync(data) : null
    if (!unpacked || unpacked.length !== size) throw new Error(`Unreadable ZIP entry: ${location}!${name}`)
    archiveEntries++
    inspect(unpacked, `${location}!${name}`)
  }
}

const inventory = []
function scan(file) {
  const location = path.relative(repo, file).replaceAll('\\', '/')
  if (/(^|\/)(?:\.env(?:\..*)?|key\.properties|STITCH_DESIGN_REPORT[^/]*|\.payment-sevqr-work)(?:\/|$)|\.(?:jks|keystore)$/i.test(location)) {
    record(location, 'forbidden-release-file')
  }
  const bytes = fs.readFileSync(file)
  files++
  inventory.push({ file: location, sha256: crypto.createHash('sha256').update(bytes).digest('hex') })
  if (/\.(?:apk|aab|zip)$/i.test(file)) archive(bytes, location)
  else inspect(bytes, location)
}
for (const input of roots) {
  const absolute = path.resolve(repo, input)
  if (!absolute.startsWith(repo + path.sep)) throw new Error('Scan targets must stay inside the repository')
  if (fs.statSync(absolute).isDirectory()) walk(absolute, scan)
  else scan(absolute)
}
console.log(JSON.stringify({
  status: findings.length ? 'FAIL' : 'PASS',
  productionProjectRef: expectedRef,
  productionProjectSeen,
  files,
  archiveEntries,
  knownPrivateValuesChecked: knownPrivate.size,
  findings,
  reviewedNonSecrets,
  inventory,
}, null, 2))
process.exitCode = findings.length ? 1 : 0
