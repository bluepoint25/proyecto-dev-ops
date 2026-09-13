import { getAccessToken } from './auth.js'

// Quitamos un posible "/" final para evitar rutas con doble barra (//productos)
const API_URL = (import.meta.env.VITE_API_URL || '').replace(/\/+$/, '')

async function llamar(descripcion, promesa) {
  try {
    const res  = await promesa
    const text = await res.text()
    let cuerpo
    try { cuerpo = JSON.parse(text) } catch { cuerpo = text }
    return { descripcion, status: res.status, ok: res.ok, cuerpo }
  } catch (err) {
    return { descripcion, status: 0, ok: false, cuerpo: `Error de red/CORS: ${err.message}` }
  }
}

/** GET /productos — requiere token */
export function getProductos() {
  return llamar(
    'GET /productos',
    fetch(`${API_URL}/productos`, {
      headers: { Authorization: `Bearer ${getAccessToken()}` },
    })
  )
}

/** POST /productos — solo admin (el API Gateway valida el token; el rol lo valida el front) */
export function crearProducto(producto) {
  return llamar(
    'POST /productos',
    fetch(`${API_URL}/productos`, {
      method:  'POST',
      headers: {
        Authorization:  `Bearer ${getAccessToken()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(producto),
    })
  )
}
