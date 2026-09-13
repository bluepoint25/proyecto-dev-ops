import { useEffect, useState, useRef } from 'react'
import {
  login, logout, procesarRetorno,
  getTokens, getAccessToken, getRol,
  decodificarJwt, estaExpirado, configuracionIncompleta,
} from './auth.js'
import { getProductos, crearProducto } from './api.js'

// Versión de la aplicación (se muestra en el footer)
const APP_VERSION = '1.1.0'

// ─── Productos iniciales ─────────────────────────────────────────────────────
const PRODUCTOS_INICIALES = [
  { id: 1, nombre: 'Laptop Pro 15"',   precio: 899990, stock: 10 },
  { id: 2, nombre: 'Mouse Inalámbrico', precio: 24990,  stock: 50 },
  { id: 3, nombre: 'Teclado Mecánico',  precio: 59990,  stock: 25 },
]

export default function App() {
  const [tokens,    setTokens]    = useState(getTokens())
  const [error,     setError]     = useState(null)
  const [productos, setProductos] = useState(PRODUCTOS_INICIALES)
  const [cargando,  setCargando]  = useState(false)
  const [resultado, setResultado] = useState(null)

  // Estado del formulario para nuevo producto (solo admin)
  const [nuevoNombre,  setNuevoNombre]  = useState('')
  const [nuevoPrecio,  setNuevoPrecio]  = useState('')
  const [nuevoStock,   setNuevoStock]   = useState('')

  // Guard: React StrictMode ejecuta useEffect 2 veces en desarrollo.
  // El "code" es de un solo uso, así que evitamos procesarlo dos veces.
  const yaProcesado = useRef(false)

  // Procesar retorno de Cognito (?code=...)
  useEffect(() => {
    if (yaProcesado.current) return
    yaProcesado.current = true

    procesarRetorno()
      .then(nuevos => nuevos && setTokens(nuevos))
      .catch(e => setError(e.message))
  }, [])

  const sesionActiva = Boolean(tokens) && !estaExpirado(getAccessToken())
  const rol          = sesionActiva ? getRol() : null
  const claims       = decodificarJwt(sesionActiva ? tokens?.id_token : null)
  const incompleto   = configuracionIncompleta()

  // ─── Cargar productos desde API Gateway (backend Spring Boot) ────────────
  async function cargarProductos() {
    setCargando(true)
    const res = await getProductos()
    setResultado(res)
    // El backend devuelve un array de { id, nombre, precio, stock }
    if (res.ok && Array.isArray(res.cuerpo)) {
      setProductos(res.cuerpo)
    }
    setCargando(false)
  }

  // ─── Agregar producto (solo admin) ───────────────────────────────────────
  async function agregarProducto(e) {
    e.preventDefault()
    if (!nuevoNombre || !nuevoPrecio || !nuevoStock) return

    // El backend genera el id; enviamos solo los datos
    const nuevo = {
      nombre: nuevoNombre,
      precio: Number(nuevoPrecio),
      stock:  Number(nuevoStock),
    }

    setCargando(true)
    const res = await crearProducto(nuevo)
    setResultado(res)
    setNuevoNombre('')
    setNuevoPrecio('')
    setNuevoStock('')

    // Recargamos desde el backend para reflejar lo que quedó en la BD
    if (res.ok) {
      await cargarProductos()
    }
    setCargando(false)
  }

  // ─── Render: configuración incompleta ────────────────────────────────────
  if (incompleto.length > 0) {
    return (
      <main>
        <h1>⚠️ Configuración incompleta</h1>
        <p>Faltan variables de entorno: <strong>{incompleto.join(', ')}</strong></p>
        <p>Crea el archivo <code>frontend/.env.local</code> con los valores de Terraform.</p>
      </main>
    )
  }

  // ─── Render: sin sesión ───────────────────────────────────────────────────
  if (!sesionActiva) {
    return (
      <main>
        <h1>🛒 Pedidos360</h1>
        {error && <p className="error">{error}</p>}
        <p>Inicia sesión para ver y gestionar productos.</p>
        <button onClick={login}>Iniciar sesión con Cognito</button>
      </main>
    )
  }

  // ─── Render: sesión activa ────────────────────────────────────────────────
  return (
    <main>
      <header>
        <h1>🛒 Pedidos360</h1>
        <div className="usuario-info">
          <span>
            {claims?.email} — rol: <strong>{rol === 'admin' ? '👑 Admin' : '👤 Usuario'}</strong>
          </span>
          <button className="secundario" onClick={logout}>Cerrar sesión</button>
        </div>
      </header>

      {error && <p className="error">{error}</p>}

      {/* ── Tabla de productos ── */}
      <section>
        <div className="seccion-header">
          <h2>Productos</h2>
          <button onClick={cargarProductos} disabled={cargando}>
            {cargando ? 'Cargando…' : '↻ Actualizar desde API'}
          </button>
        </div>

        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Nombre</th>
              <th>Precio</th>
              <th>Stock</th>
            </tr>
          </thead>
          <tbody>
            {productos.map(p => (
              <tr key={p.id}>
                <td>{p.id}</td>
                <td>{p.nombre}</td>
                <td>${Number(p.precio).toLocaleString('es-CL')}</td>
                <td>{p.stock}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {/* ── Formulario solo para admin ── */}
      {rol === 'admin' && (
        <section>
          <h2>➕ Agregar producto</h2>
          <form onSubmit={agregarProducto} className="form-producto">
            <input
              type="text"
              placeholder="Nombre del producto"
              value={nuevoNombre}
              onChange={e => setNuevoNombre(e.target.value)}
              required
            />
            <input
              type="number"
              placeholder="Precio"
              value={nuevoPrecio}
              onChange={e => setNuevoPrecio(e.target.value)}
              required
              min="1"
            />
            <input
              type="number"
              placeholder="Stock"
              value={nuevoStock}
              onChange={e => setNuevoStock(e.target.value)}
              required
              min="0"
            />
            <button type="submit" disabled={cargando}>
              {cargando ? 'Guardando…' : 'Agregar producto'}
            </button>
          </form>
        </section>
      )}

      {rol !== 'admin' && (
        <section>
          <p className="info">
            ℹ️ Solo los administradores pueden agregar productos.
          </p>
        </section>
      )}

      {/* ── Respuesta de la API ── */}
      {resultado && (
        <section>
          <h2>Respuesta API</h2>
          <div className={resultado.ok ? 'resultado ok' : 'resultado falla'}>
            <p><strong>{resultado.descripcion}</strong> → HTTP {resultado.status || 'sin respuesta'}</p>
            <pre>{JSON.stringify(resultado.cuerpo, null, 2)}</pre>
          </div>
        </section>
      )}

      {/* ── Footer con la versión de la app ── */}
      <footer className="app-footer">
        <span>Pedidos360 · versión {APP_VERSION}</span>
      </footer>
    </main>
  )
}
