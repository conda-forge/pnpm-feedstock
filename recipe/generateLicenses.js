// Parse pnpm licenses list --json output and generate a simple license disclaimer.
// Replaces @quantco/pnpm-licenses which fails on Windows due to virtual store path resolution
// for workspace packages like @pnpm/meta-updater.

const fs = require('fs')

// Read all of stdin
const chunks = []
process.stdin.resume()
process.stdin.on('data', chunk => chunks.push(chunk))
process.stdin.on('end', () => {
  const input = Buffer.concat(chunks).toString('utf8').trim()
  if (!input) {
    console.error('No license data received from stdin')
    process.exit(1)
  }

  let data
  try {
    data = JSON.parse(input)
  } catch (e) {
    console.error('Failed to parse JSON input:', e.message)
    process.exit(1)
  }

  // Filter to @pnpm/* packages
  const lines = []
  for (const [key, entry] of Object.entries(data)) {
    // entry can be an object {name, version, license, ...} or the name may be embedded in the key
    const name = (entry && entry.name) ? entry.name : key.replace(/@([\d.]+)$/, '')
    if (!name.startsWith('@pnpm/')) continue

    const version = (entry && entry.version) ? entry.version : ''
    const license = (entry && entry.license) ? entry.license : 'Unknown'
    const homepage = (entry && entry.homepage) ? entry.homepage : ''
    const author = (entry && entry.author) ? (typeof entry.author === 'string' ? entry.author : entry.author.name || '') : ''

    lines.push(`${name}@${version}`)
    lines.push(`License: ${license}`)
    if (homepage) lines.push(`Homepage: ${homepage}`)
    if (author) lines.push(`Author: ${author}`)
    lines.push('')
  }

  // Write output
  const output = lines.join('\n')
  const outFile = process.argv[2] || 'ThirdPartyLicenses.txt'
  fs.writeFileSync(outFile, output, 'utf8')
  console.error(`Wrote ${lines.filter(l => l).length} lines to ${outFile}`)
})
