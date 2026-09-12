# Pedidos360 — Repositorio DevOps (Ingeniería DevOps, EP1)

Sistema FullStack seguro desplegado en AWS. Un frontend en **React** se autentica
contra **AWS Cognito** (IDaaS) mediante **OAuth2 Authorization Code + PKCE**, y
consume un backend **Spring Boot** protegido por un **API Gateway con JWT
Authorizer** y autorización por scopes. El backend corre en **ECS Fargate** y
persiste los datos en **RDS PostgreSQL**.

Este repositorio se usa además como base del **pipeline DevOps** del curso:
implementa **GitFlow**, integra **GitHub Actions** para CI/CD y documenta las
convenciones de trabajo colaborativo del equipo.

> Guía completa de buenas prácticas (naming de ramas, commits, merges, revisión):
> ver [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Estrategia de ramificación y por qué GitFlow

### Modelos evaluados

| Modelo                | Idea central                                                        | Cuándo conviene                                          |
|-----------------------|---------------------------------------------------------------------|----------------------------------------------------------|
| **GitFlow**           | Ramas de larga vida (`main`, `develop`) + ramas de apoyo (`feature/*`, `hotfix/*`, `release/*`). | Versiones planificadas, equipos con revisión formal, releases claras. |
| **GitHub Flow**       | Solo `main` + ramas de feature con PR y despliegue continuo.        | Entrega continua, apps web con despliegues muy frecuentes. |
| **Trunk-Based Dev.**  | Todos integran a un único tronco (`main`) con commits muy pequeños y frecuentes, detrás de feature flags. | Equipos con CI muy maduro y alta frecuencia de integración. |

### Elección: GitFlow

Elegimos **GitFlow** para este encargo por estas razones:

1. **Encaja con el objetivo de la evaluación.** El encargo pide explícitamente
   las ramas `main`, `develop`, `feature/<nombre>` y `hotfix/<nombre>`; esas
   ramas *son* la estructura de GitFlow.
2. **Separa lo estable de lo que está en desarrollo.** `main` siempre refleja lo
   desplegable; `develop` acumula lo que aún se integra. Esto da trazabilidad
   clara de qué está en producción.
3. **Modela el trabajo en pareja/equipo.** Cada persona trabaja en su
   `feature/*` aislada y la integra por Pull Request, lo que habilita revisión
   de código antes del merge.
4. **Maneja urgencias de producción.** Las ramas `hotfix/*` nacen de `main`,
   permitiendo arreglar producción sin arrastrar trabajo a medio hacer de
   `develop`.

Trunk-based sería preferible con integración continua muy madura y despliegues
varias veces al día; GitHub Flow es ideal para entrega continua pura. Para el
contexto del curso (releases planificadas, revisión formal por PR y aprendizaje
del control de versiones), **GitFlow es el que mejor equilibra control,
trazabilidad y colaboración.**

### Ramas del repositorio

- `main` — código estable/desplegable. Solo entra por PR.
- `develop` — integración de features. Solo entra por PR.
- `feature/<nombre>` — funcionalidades nuevas (nacen de `develop`).
- `hotfix/<nombre>` — correcciones urgentes (nacen de `main`).

---

## Arquitectura

```
  Usuario (navegador)
    │
    ▼
  Frontend React ── AWS Amplify (hosting HTTPS)
    │
    │  1) login OAuth2 + PKCE
    ▼
  AWS Cognito (IDaaS) ──── Lambda Pre-Token Generation
    │  emite JWT                (grupo del usuario → scope)
    │
    │  2) Authorization: Bearer <access_token>
    ▼
  AWS API Gateway (HTTP API)
    │  valida firma, issuer, audiencia, expiración y SCOPE
    │  401 sin token · 403 sin el scope requerido
    ▼
  Backend Spring Boot (ECS Fargate)  ──►  RDS PostgreSQL
```

La seguridad se aplica en el borde (API Gateway). El backend revalida el token
como segunda capa (defensa en profundidad).

---

## Componentes

| Componente     | Tecnología                | Servicio AWS       | Rol                                          |
|----------------|---------------------------|--------------------|----------------------------------------------|
| Frontend       | React 18 + Vite 5         | Amplify Hosting    | Interfaz, login OAuth2/PKCE, consumo de API   |
| IDaaS          | —                         | Cognito User Pool  | Autenticación, emisión de tokens JWT          |
| Puente permisos| Node.js 20                | Lambda             | Inyecta scopes en el token según el grupo     |
| API Manager    | —                         | API Gateway (HTTP) | Valida JWT, autoriza por scope, CORS          |
| Backend        | Java 21 + Spring Boot 3.3 | ECS Fargate        | Resource Server, CRUD de productos            |
| Base de datos  | PostgreSQL 16             | RDS                | Persistencia                                  |
| Registro imagen| Docker                    | ECR                | Almacena la imagen del backend                |
| IaC            | Terraform ~5.0            | —                  | Define toda la infraestructura                |

---

## Seguridad: roles y scopes

| Usuario | Email                 | Grupo    | Scopes                          |
|---------|-----------------------|----------|---------------------------------|
| Admin   | admin@pedidos360.cl   | editores | productos/read, productos/write |
| Normal  | usuario@pedidos360.cl | lectores | productos/read                  |

Una **Lambda Pre-Token Generation** lee el grupo del usuario e inyecta los scopes
en el access token. El API Gateway autoriza cada ruta según el scope:

| Petición                          | Respuesta esperada                     |
|-----------------------------------|----------------------------------------|
| `GET /productos` sin token        | **401** (no hay credencial)            |
| `GET /productos` con token        | **200** (tiene `productos/read`)       |
| `POST /productos` usuario normal  | **403** (falta `productos/write`)      |
| `POST /productos` admin           | **200/201** (tiene `productos/write`)  |

---

## Estructura del proyecto

```
proyecto/
├── README.md
├── .gitignore
├── frontend/                     React + Vite
│   └── src/
│       ├── auth.js               OAuth2 + PKCE + manejo de tokens
│       ├── api.js                llamadas al API Gateway
│       └── App.jsx               UI, tabla de productos, lógica de rol
├── backend/                      Spring Boot (Java 21)
│   ├── src/main/java/cl/pedidos360/backend/
│   │   ├── Producto.java             entidad JPA
│   │   ├── ProductoRepository.java   repositorio JPA
│   │   ├── ProductoController.java   endpoints GET/POST /productos
│   │   ├── SecurityConfig.java       Resource Server + validación JWT
│   │   └── DataSeeder.java           3 productos iniciales
│   ├── Dockerfile                compila con Maven y corre el jar (linux/amd64)
│   └── publicar-ecs.sh           build + push a ECR + redeploy ECS (guía 1.3.9)
├── terraform/                    Infraestructura como código
│   ├── cognito.tf                User Pool, cliente SPA, grupos, resource server
│   ├── lambda.tf                 Lambda Pre-Token Generation
│   ├── apigateway.tf             HTTP API, JWT Authorizer, rutas con scopes
│   ├── ecs.tf                    ECR, cluster, task definition, servicio Fargate
│   ├── rds.tf                    PostgreSQL
│   └── amplify.tf                hosting del frontend
└── .github/workflows/            4 pipelines CI/CD
```

---

## Endpoints de la API

| Método | Ruta          | Scope requerido    | Descripción             |
|--------|---------------|--------------------|-------------------------|
| GET    | `/productos`  | `productos/read`   | Lista los productos     |
| POST   | `/productos`  | `productos/write`  | Crea un producto        |

El backend expone además `/actuator/health` (público) para el health check de ECS.

---

## Requisitos previos

- Node.js ≥ 22
- Java 21 + Maven
- Docker Desktop (para construir la imagen del backend)
- Terraform ≥ 1.5
- AWS CLI configurado con credenciales válidas (región `us-east-1`)

---

## Despliegue

### 1. Infraestructura (Terraform)

```bash
cd terraform
terraform init
terraform apply
```

### 2. Backend (imagen a ECR + ECS)

```bash
cd ../backend
./publicar-ecs.sh
```

Luego se apunta el API Gateway a la IP pública de la task ECS.

### 3. Frontend (build + publicar en Amplify)

```bash
cd ../frontend
npm install
npm run build
# publicar: create-deployment → PUT del zip → start-deployment (guía 1.2.9e)
```

---

## Pipelines (CI/CD)

Workflows de GitHub Actions en `.github/workflows/`:

| Pipeline               | Disparador                                   | Qué hace                                   |
|------------------------|----------------------------------------------|--------------------------------------------|
| `ci.yml`               | **push a `develop`** y **PR a `main`**       | Compila backend y frontend (quality gate)  |
| `frontend-build.yml`   | push a `frontend/**`, PR a `main`            | `npm install` + `npm run build`            |
| `frontend-deploy.yml`  | manual                                       | build + publicar en Amplify                |
| `backend-build.yml`    | push a `backend/**`, PR a `main`             | `mvn clean package` (compila y prueba)     |
| `backend-deploy.yml`   | manual                                       | build imagen + push ECR + redeploy ECS     |

### Rol de la acción de CI en CI/CD

`ci.yml` es la **acción de integración continua** exigida por la evaluación. Se
ejecuta automáticamente en **cada push a `develop`** (valida la integración de
cada feature) y en **cada pull request hacia `main`** (valida el candidato a
release antes de que llegue a producción).

Su rol es actuar como **puerta de calidad**: si el backend o el frontend no
compilan, la acción falla y el Pull Request no debe mergearse. Así, ningún
cambio roto entra a `develop` ni a `main`. Esta es la fase de **Integración
Continua (CI)**; los pipelines `*-deploy.yml` cubren la **Entrega/Despliegue
Continuo (CD)** hacia AWS.

Los pipelines de **despliegue** requieren estos secrets en el repositorio
(Settings → Secrets and variables → Actions):

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

> Las credenciales de AWS Academy son temporales; deben renovarse en los secrets
> cuando expiran. Los pipelines de compilación no dependen de AWS.

---

## Credenciales de prueba

| Usuario  | Email                   | Contraseña   | Rol    |
|----------|-------------------------|--------------|--------|
| Admin    | admin@pedidos360.cl     | Pedidos2025! | editor |
| Normal   | usuario@pedidos360.cl   | Pedidos2025! | lector |

> Las contraseñas por defecto son exclusivas del entorno de laboratorio. En
> producción se usaría AWS Secrets Manager y credenciales gestionadas fuera del código.
