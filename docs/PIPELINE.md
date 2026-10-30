# Pipeline CI/CD del microservicio Pedidos360 (Evaluación Parcial 2)

Workflow: [`.github/workflows/cicd-backend.yml`](../.github/workflows/cicd-backend.yml)

## Flujo

```
 push / PR
    │
    ▼
 ┌────────┐   ┌─────────┐   ┌─────────────┐   ┌────────────┐   ┌────────────────┐
 │  test  │──►│  sonar  │──►│ build-image │──►│ scan-image │──►│ deploy-staging │
 │ JUnit  │   │ quality │   │   Docker    │   │   Trivy    │   │ Docker Compose │
 │ Jacoco │   │  gate   │   │ tag = SHA   │   │ HIGH/CRIT  │   │ + smoke tests  │
 └────────┘   └─────────┘   └─────────────┘   └────────────┘   │ + push a GHCR  │
      │                                                         └────────────────┘
      └──► validar-k8s (kubeconform sobre k8s/)
```

Cada etapa usa `needs`, por lo que **una falla bloquea todo lo posterior**.

| Etapa | Qué hace | Cuándo bloquea | Indicador |
|-------|----------|----------------|-----------|
| `test` | `mvn verify`: 10 pruebas (JUnit 5 + MockMvc + Spring Security Test) y reporte Jacoco | Una prueba falla o la cobertura de líneas es < 60 % (`coverage.minimum` en `pom.xml`) | IE2 |
| `dependency-review` | En PRs revisa las dependencias nuevas/cambiadas (requiere *Dependency graph* activo en el repo) | Una dependencia nueva tiene vulnerabilidad HIGH o superior | IE3 |
| `sonar` | Análisis estático en SonarCloud con `sonar.qualitygate.wait=true` | El quality gate falla o falta `SONAR_TOKEN` | IE3 |
| `build-image` | Construye el `Dockerfile` multi-stage; etiqueta la imagen con el SHA del commit | El build falla | IE1 |
| `scan-image` | Trivy escanea la imagen | Hay vulnerabilidades HIGH/CRITICAL con corrección disponible | IE3 |
| `deploy-staging` | `docker compose up --wait` con la imagen construida, smoke tests y verificación del commit; desde `main` publica la imagen en GHCR | Compose no queda saludable, un smoke test falla o el commit de la imagen no coincide | IE4 |
| `validar-k8s` | Valida con kubeconform los manifiestos de `k8s/` (solo esquema; no despliega en un cluster) | Un manifiesto no cumple el esquema y bloquea `deploy-staging` | IE5 |

Además **Dependabot** (`.github/dependabot.yml`) revisa semanalmente Maven, npm, Docker y GitHub Actions y abre PRs hacia `develop`.

## Contenedores (IE1)

`backend/Dockerfile` es multi-stage: compila con `maven:3.9-eclipse-temurin-21` y ejecuta con `eclipse-temurin:21-jre`. Incluye:

- Usuario no root (`USER app`).
- `HEALTHCHECK` sobre `/actuator/health`.
- `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=75` para que la JVM respete el límite de memoria del contenedor.
- Etiquetas OCI `revision` y `version` inyectadas por el pipeline.

## Seguridad y escalabilidad (IE3)

- Quality gate de Sonar y Trivy bloquean el avance (no solo alertan).
- Permisos mínimos del `GITHUB_TOKEN` (`contents: read`; `packages: write` solo donde se publica).
- Los PR de Dependabot/forks no reciben secretos: ahí Sonar se omite y el control lo dan `dependency-review` y Trivy.
- Pendiente recomendado: fijar las `uses:` de terceros (p. ej. `trivy-action`) por SHA de commit.
- Contenedor sin privilegios (UID 10001); en Kubernetes `runAsNonRoot`, `allowPrivilegeEscalation: false` y `capabilities.drop: ALL`.
- Escalabilidad: límites de CPU/memoria en Compose y Kubernetes, `HorizontalPodAutoscaler` (2–5 réplicas al 70 % de CPU; requiere metrics-server en el cluster), `RollingUpdate` sin caída y `PodDisruptionBudget`.

## Orquestación (IE5)

- **Docker Compose** (`docker-compose.yml`): backend + PostgreSQL con healthchecks, `depends_on: service_healthy`, red dedicada, volumen y límites de recursos. Es el entorno que despliega el pipeline.
- **Kubernetes** (`k8s/`): Deployment, Service, HPA, PDB, Secret y StatefulSet de PostgreSQL. Para probar localmente (minikube/kind/Docker Desktop):

```bash
kubectl apply -f k8s/postgres.yaml -f k8s/backend.yaml
kubectl -n pedidos360 get pods,hpa
```

## Trazabilidad (IE4)

Se puede seguir un cambio de punta a punta:

1. **Commit / PR** (GitFlow + Conventional Commits, ver `CONTRIBUTING.md`) →
2. **Run de Actions** (ligado al SHA) →
3. **Imagen** `ghcr.io/<owner>/pedidos360-backend:<SHA>` con la etiqueta OCI `org.opencontainers.image.revision=<SHA>` →
4. **Despliegue**: el job verifica que el commit de la imagen sea el que se ejecuta y deja un resumen (commit, rama, imagen, autor, run) en la pestaña *Summary* →
5. **Servicio en ejecución**: `GET /info` informa nombre, versión y **commit** (`GIT_SHA`), y el smoke test verifica que coincida con el commit del run.

## Calidad

- Pruebas: 401 sin token, 403 sin scope, 200/201 con scope correcto, `/info` público y carga del contexto con H2.
- Cobertura mínima exigida y reporte Jacoco publicado como artefacto de cada run.
- Protección de ramas recomendada para `main`: exigir que pasen `test`, `sonar`, `build-image` y `scan-image` antes de mergear.

## Configuración necesaria (una sola vez)

1. En [SonarCloud](https://sonarcloud.io) importar el repositorio y generar un token. Ajustar `sonar.projectKey` y `sonar.organization` en `backend/pom.xml` si difieren. Desactivar *Automatic Analysis* (se usa el análisis desde CI).
2. En GitHub: *Settings → Secrets and variables → Actions → New repository secret* → `SONAR_TOKEN`.
3. (Opcional) secret `STAGING_DB_PASSWORD`; sin él se usa un valor de ejemplo solo válido en el runner efímero.
4. *Settings → Actions → General → Workflow permissions*: permitir lectura y escritura para publicar en GHCR.
5. *Settings → Branches*: regla de protección en `main` con los checks anteriores.

## Uso de Inteligencia Artificial

Declarar aquí (obligatorio según la pauta) qué herramientas de IA se usaron y para qué. Ejemplo de borrador: *Claude Code (Anthropic) se usó como apoyo para generar la estructura inicial del workflow, Dockerfile, manifiestos y pruebas; el equipo revisó, ejecutó y validó cada archivo.* **Edítenlo para que refleje lo que realmente hicieron.**

## Conclusiones y reflexiones individuales

> La pauta prohíbe usar IA para redactar esta sección. Cada integrante debe escribir aquí, con sus propias palabras, qué aprendió y cuál fue su contribución.

- **Integrante 1:** _(pendiente)_
- **Integrante 2:** _(pendiente)_
