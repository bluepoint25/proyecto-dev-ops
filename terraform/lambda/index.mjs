/**
 * Pre Token Generation trigger V2_0
 * Lee los grupos del usuario e inyecta los scopes correspondientes
 * en el access token ANTES de que Cognito lo firme.
 *
 * Grupos → Scopes:
 *   editores → productos/read + productos/write
 *   lectores → productos/read
 */

const SCOPES_POR_GRUPO = {
  editores: ['productos/read', 'productos/write'],
  lectores: ['productos/read'],
}

export const handler = async (event) => {
  // Los grupos del usuario vienen en el contexto de la petición
  const grupos = event.request?.groupConfiguration?.groupsToOverride ?? []

  // Calculamos los scopes únicos que corresponden a los grupos
  const scopesSet = new Set()
  for (const grupo of grupos) {
    const scopes = SCOPES_POR_GRUPO[grupo] ?? []
    scopes.forEach(s => scopesSet.add(s))
  }
  const scopesExtra = [...scopesSet]

  // Log para CloudWatch — útil para depurar
  console.log(JSON.stringify({
    usuario:  event.userName,
    grupos,
    scopesExtra,
  }))

  // Inyectamos los scopes en el access token
  event.response = {
    claimsAndScopeOverrideDetails: {
      accessTokenGeneration: {
        scopesToAdd: scopesExtra,
      },
    },
  }

  return event
}
