const encoder = new TextEncoder()

const base64url = (bytes) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

const pemToBytes = (pem) =>
  Uint8Array.from(atob(pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')), (c) => c.charCodeAt(0))

async function providerToken(env) {
  const header = base64url(encoder.encode(JSON.stringify({ alg: 'ES256', kid: env.APNS_KEY_ID })))
  const claims = base64url(encoder.encode(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) })))
  const key = await crypto.subtle.importKey('pkcs8', pemToBytes(env.APNS_KEY), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, encoder.encode(`${header}.${claims}`))
  return `${header}.${claims}.${base64url(signature)}`
}

const isToken = (value) => typeof value === 'string' && /^[0-9a-f]{32,200}$/.test(value)

function payload(body, now) {
  const state = { remaining: body.remaining, limit: body.limit }
  const aps = { timestamp: now, 'content-state': state }
  if (body.kind === 'start') {
    aps.event = 'start'
    aps['attributes-type'] = 'LiveLimitAttributes'
    aps.attributes = { groupID: body.groupID, name: body.name }
  } else {
    aps.event = body.kind
  }
  if (body.kind === 'end') {
    aps['dismissal-date'] = now + 60
  } else {
    aps.alert = { title: body.name, body: `Il te reste ${body.remaining} min` }
  }
  return { aps }
}

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return new Response(null, { status: 405 })
    const body = await request.json().catch(() => null)
    if (!body || !['start', 'update', 'end'].includes(body.kind)) return new Response(null, { status: 400 })
    if (!Number.isInteger(body.remaining) || !Number.isInteger(body.limit) || typeof body.name !== 'string' || body.name.length > 60) {
      return new Response(null, { status: 400 })
    }
    const kind = body.kind === 'start' || !isToken(body.updateToken) ? 'start' : body.kind
    if (kind === 'start' && body.kind === 'end') return new Response(null, { status: 204 })
    const token = kind === 'start' ? body.startToken : body.updateToken
    if (!isToken(token)) return new Response(null, { status: 400 })
    const now = Math.floor(Date.now() / 1000)
    const apns = await fetch(`https://api.push.apple.com/3/device/${token}`, {
      method: 'POST',
      headers: {
        authorization: `bearer ${await providerToken(env)}`,
        'apns-push-type': 'liveactivity',
        'apns-topic': `${env.APNS_TOPIC}.push-type.liveactivity`,
        'apns-priority': '10',
      },
      body: JSON.stringify(payload({ ...body, kind }, now)),
    })
    return new Response(null, { status: apns.ok ? 204 : 502 })
  },
}
