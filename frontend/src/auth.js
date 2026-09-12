// ─── Configuración desde variables de entorno ────────────────────────────────
const cfg = {
  dominio:     import.meta.env.VITE_COGNITO_DOMAIN,
  clientId:    import.meta.env.VITE_COGNITO_CLIENT_ID,
  redirectUri: import.meta.env.VITE_REDIRECT_URI,
  scopes:      'openid email profile productos/read productos/write',
}

export const config = cfg

/** Devuelve las claves que quedaron sin valor */
export function configuracionIncompleta() {
  return Object.entries(cfg)
    .filter(([, v]) => !v)
    .map(([k]) => k)
}

// ─── Utilidades PKCE ─────────────────────────────────────────────────────────
function base64Url(buffer) {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

function aleatorioBase64Url(bytes = 32) {
  const buf = new Uint8Array(bytes)
  crypto.getRandomValues(buf)
  return base64Url(buf)
}

async function calcularChallenge(verifier) {
  const hash = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(verifier)
  )
  return base64Url(hash)
}

// ─── Claves de sessionStorage ────────────────────────────────────────────────
const CLAVE_VERIFIER = 'p360.pkce_verifier'
const CLAVE_STATE    = 'p360.state'
const CLAVE_TOKENS   = 'p360.tokens'

// ─── Login: redirige al Hosted UI de Cognito ─────────────────────────────────
export async function login() {
  const verifier   = aleatorioBase64Url()
  const challenge  = await calcularChallenge(verifier)
  const state      = aleatorioBase64Url(16)

  sessionStorage.setItem(CLAVE_VERIFIER, verifier)
  sessionStorage.setItem(CLAVE_STATE, state)

  const params = new URLSearchParams({
    response_type:         'code',
    client_id:             cfg.clientId,
    redirect_uri:          cfg.redirectUri,
    scope:                 cfg.scopes,
    state,
    code_challenge:        challenge,
    code_challenge_method: 'S256',
  })

  window.location.assign(`${cfg.dominio}/oauth2/authorize?${params}`)
}

// ─── Logout: cierra sesión en el IDaaS ───────────────────────────────────────
export function logout() {
  sessionStorage.removeItem(CLAVE_TOKENS)
  const params = new URLSearchParams({
    client_id:  cfg.clientId,
    logout_uri: cfg.redirectUri,
  })
  window.location.assign(`${cfg.dominio}/logout?${params}`)
}

// ─── Tokens ──────────────────────────────────────────────────────────────────
export function getTokens() {
  const raw = sessionStorage.getItem(CLAVE_TOKENS)
  return raw ? JSON.parse(raw) : null
}

export function getAccessToken() {
  return getTokens()?.access_token ?? null
}

export function getIdToken() {
  return getTokens()?.id_token ?? null
}

function limpiarUrl() {
  window.history.replaceState({}, document.title, window.location.pathname)
}

// ─── Decodificar JWT (solo para leer claims, NO verifica firma) ───────────────
export function decodificarJwt(token) {
  if (!token) return null
  try {
    const payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    const bytes   = Uint8Array.from(atob(payload), c => c.charCodeAt(0))
    return JSON.parse(new TextDecoder().decode(bytes))
  } catch {
    return null
  }
}

export function estaExpirado(token) {
  const exp = decodificarJwt(token)?.exp
  return exp ? exp * 1000 < Date.now() : true
}

/** Lee el rol desde los claims del ID Token.
 *  El grupo "editores" tiene permiso de escritura (productos/write) y el grupo
 *  "lectores" solo lectura (productos/read). */
export function getRol() {
  const claims = decodificarJwt(getIdToken())
  // Cognito pone los grupos en "cognito:groups"
  const grupos = claims?.['cognito:groups'] ?? []
  return grupos.includes('editores') ? 'admin' : 'user'
}

// ─── Procesar el retorno del Hosted UI (?code=...) ───────────────────────────
export async function procesarRetorno() {
  const url   = new URL(window.location.href)
  const code  = url.searchParams.get('code')
  const state = url.searchParams.get('state')
  const error = url.searchParams.get('error')

  if (error) {
    limpiarUrl()
    throw new Error(`${error}: ${url.searchParams.get('error_description') ?? ''}`)
  }

  if (!code) return null

  if (state !== sessionStorage.getItem(CLAVE_STATE)) {
    limpiarUrl()
    throw new Error('State no coincide. Posible ataque CSRF.')
  }

  const verifier = sessionStorage.getItem(CLAVE_VERIFIER)
  if (!verifier) {
    limpiarUrl()
    throw new Error('No hay code_verifier. Vuelve a iniciar sesión.')
  }

  const respuesta = await fetch(`${cfg.dominio}/oauth2/token`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    new URLSearchParams({
      grant_type:    'authorization_code',
      client_id:     cfg.clientId,
      code,
      redirect_uri:  cfg.redirectUri,
      code_verifier: verifier,
    }),
  })

  const datos = await respuesta.json()
  limpiarUrl()
  sessionStorage.removeItem(CLAVE_VERIFIER)
  sessionStorage.removeItem(CLAVE_STATE)

  if (!respuesta.ok) {
    throw new Error(`/token respondió ${respuesta.status}: ${datos.error ?? 'error desconocido'}`)
  }

  sessionStorage.setItem(CLAVE_TOKENS, JSON.stringify(datos))
  return datos
}
