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
      ├──► secretos (gitleaks): puerta adicional antes de build-image
      └──► validar-k8s (kubeconform) ──┐
                                        ├──► deploy-staging ──► release-produccion (main + aprobación)
 build-image ──► scan-image ──► k8s-kind ┘     (Compose + smoke)   (GHCR v<run>/SHA + GitHub Release)
```

Cada etapa usa `needs`, por lo que **una falla bloquea todo lo posterior**.

| Etapa | Qué hace | Cuándo bloquea | Indicador |
|-------|----------|----------------|-----------|
| `test` | `mvn verify`: 13 pruebas (JUnit 5, MockMvc, Spring Security Test y Testcontainers con PostgreSQL real) y reporte Jacoco | Una prueba falla o la cobertura de líneas es < 80 % (`coverage.minimum` en `pom.xml`) | IE2 |
| `dependency-review` | En PRs revisa las dependencias nuevas/cambiadas (requiere *Dependency graph* activo en el repo) | Una dependencia nueva tiene vulnerabilidad HIGH o superior | IE3 |
| `sonar` | Levanta SonarQube Community como contenedor efímero en el runner (sin cuenta, sin costo, sin secretos) y analiza con `sonar.qualitygate.wait=true` | El quality gate falla | IE3 |
| `secretos` | gitleaks revisa todo el historial buscando credenciales | Encuentra una credencial | IE3 |
| `build-image` | Construye las imágenes de backend y frontend (multi-stage); las etiqueta con el SHA del commit | El build falla | IE1 |
| `scan-image` | Trivy escanea ambas imágenes | Hay vulnerabilidades HIGH/CRITICAL con corrección disponible | IE3 |
| `deploy-staging` | `docker compose up --wait` (db + backend + frontend) con las imágenes construidas, smoke tests y verificación del commit | Compose no queda saludable, un smoke test falla o el commit no coincide | IE4 |
| `release-produccion` | Solo en `main`, con aprobación del entorno `production`: publica imágenes en GHCR (`<SHA>`, `v<run>`, `latest`) y crea un GitHub Release con el commit | Falla el login/push o el revisor rechaza | IE4 |
| `validar-k8s` | kubeconform valida el esquema de `k8s/` | Un manifiesto es inválido (bloquea `deploy-staging`) | IE5 |
| `k8s-kind` | Crea un cluster Kubernetes efímero (kind), despliega Postgres + backend + frontend, espera `rollout status` y verifica `/info` y el commit | Un pod no queda listo o el smoke test falla (bloquea `deploy-staging`) | IE5 |

Además **Dependabot** (`.github/dependabot.yml`) revisa semanalmente Maven, npm, Docker y GitHub Actions y abre PRs hacia `develop`.

## Contenedores (IE1)

`backend/Dockerfile` y `frontend/Dockerfile` (nginx sin privilegios) son multi-stage. El del backend: compila con `maven:3.9-eclipse-temurin-21` y ejecuta con `eclipse-temurin:21-jre`. Incluye:

- Usuario no root (`USER app`).
- `HEALTHCHECK` sobre `/actuator/health`.
- `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=75` para que la JVM respete el límite de memoria del contenedor.
- Etiquetas OCI `revision` y `version` inyectadas por el pipeline.

## Seguridad y escalabilidad (IE3)

- Quality gate de Sonar y Trivy bloquean el avance (no solo alertan).
- Permisos mínimos del `GITHUB_TOKEN` (`contents: read`; `packages: write` solo donde se publica).
- Sonar no necesita secretos, por lo que también corre en PRs de Dependabot y de forks.
- Todas las `uses:` de terceros están fijadas por SHA de commit.
- gitleaks bloquea credenciales en el historial; el Secret de Kubernetes se crea fuera del repositorio.
- Contenedor sin privilegios (UID 10001); en Kubernetes `runAsNonRoot`, `allowPrivilegeEscalation: false` y `capabilities.drop: ALL`.
- Escalabilidad: límites de CPU/memoria en Compose y Kubernetes, `HorizontalPodAutoscaler` (2–5 réplicas al 70 % de CPU; requiere metrics-server en el cluster), `RollingUpdate` sin caída y `PodDisruptionBudget`.

## Orquestación (IE5)

- **Docker Compose** (`docker-compose.yml`): backend + PostgreSQL con healthchecks, `depends_on: service_healthy`, red dedicada, volumen y límites de recursos. Es el entorno que despliega el pipeline.
- **Kubernetes** (`k8s/`): Deployments de backend y frontend, Services, Ingress, HPA, PDB y StatefulSet de PostgreSQL. El Secret `db-credentials` no se versiona. El job `k8s-kind` lo prueba en cada run. Para probar localmente (minikube/kind/Docker Desktop):

```bash
kubectl create namespace pedidos360
kubectl -n pedidos360 create secret generic db-credentials --from-literal=username=pedidos --from-literal=password=<clave>
kubectl apply -f k8s/postgres.yaml -f k8s/backend.yaml -f k8s/frontend.yaml
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

1. No se requiere cuenta ni token de Sonar: el pipeline levanta su propio SonarQube. (Alternativa: si prefieren SonarCloud, que es gratis para repos públicos, reemplazar el job `sonar`.)
2. (Opcional) secret `STAGING_DB_PASSWORD`; sin él se usa un valor de ejemplo solo válido en el runner efímero.
3. *Settings → Actions → General → Workflow permissions*: permitir lectura y escritura para publicar en GHCR.
4. *Settings → Branches*: regla de protección en `main` que exija los checks `Pruebas unitarias y cobertura`, `Analisis de codigo (SonarQube)`, `Escaneo de secretos (gitleaks)`, `Escaneo de seguridad (Trivy)` y `Probar en Kubernetes (kind)`.
5. *Settings → Environments*: crear `staging` y `production`; en `production` agregar *Required reviewers* (aprobación manual antes del release).

## Evidencias para la entrega

Capturas recomendadas (guardarlas en `docs/evidencias/` y enlazarlas aquí):

1. Run completo en verde de *CI/CD - Backend* (pestaña Actions), con todos los jobs.
2. Un run **bloqueado** (por ejemplo, subir `coverage.minimum` a 99 % o introducir un test que falle) mostrando que `build-image` y `deploy-staging` no se ejecutan.
3. Resumen del job `sonar` (bugs, vulnerabilidades, cobertura) y el quality gate en *Passed*.
4. Resumen del job `deploy-staging` (commit, rama, imágenes) y el *GitHub Release* creado.
5. Salida del job `k8s-kind` (`kubectl get pods,svc,hpa`).
6. Regla de protección de `main` y la aprobación del entorno `production`.

## Uso de Inteligencia Artificial

Declarar aquí (obligatorio según la pauta) qué herramientas de IA se usaron y para qué. Ejemplo de borrador: *Claude Code (Anthropic) se usó como apoyo para generar la estructura inicial del workflow, Dockerfile, manifiestos y pruebas; el equipo revisó, ejecutó y validó cada archivo.* **Edítenlo para que refleje lo que realmente hicieron.**

## Conclusiones y reflexiones individuales

> La pauta prohíbe usar IA para redactar esta sección. Cada integrante debe escribir aquí, con sus propias palabras, qué aprendió y cuál fue su contribución.

- **Integrante 1:** _(pendiente)_
- **Integrante 2:** _(pendiente)_
