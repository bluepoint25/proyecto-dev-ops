# Pedidos360

Sistema FullStack seguro desplegado en AWS. Un frontend en **React** se autentica
contra **AWS Cognito** mediante **OAuth2 Authorization Code + PKCE** y consume un
backend **Spring Boot** protegido por un **API Gateway con JWT Authorizer** y
autorización por scopes. El backend corre en **ECS Fargate** y persiste los datos
en **RDS PostgreSQL**.

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
  AWS Cognito ──── Lambda Pre-Token Generation
    │  emite JWT        (grupo del usuario → scope)
    │
    │  2) Authorization: Bearer <access_token>
    ▼
  AWS API Gateway (HTTP API)
    │  valida firma, issuer, audiencia, expiración y scope
    │  401 sin token · 403 sin el scope requerido
    ▼
  Backend Spring Boot (ECS Fargate)  ──►  RDS PostgreSQL
```

La seguridad se aplica en el borde (API Gateway). El backend revalida el token
como segunda capa (defensa en profundidad).

---

## Componentes

| Componente      | Tecnología                | Servicio AWS       | Rol                                          |
|-----------------|---------------------------|--------------------|----------------------------------------------|
| Frontend        | React 18 + Vite 5         | Amplify Hosting    | Interfaz, login OAuth2/PKCE, consumo de API   |
| IDaaS           | —                         | Cognito User Pool  | Autenticación, emisión de tokens JWT          |
| Puente permisos | Node.js 20                | Lambda             | Inyecta scopes en el token según el grupo     |
| API Manager     | —                         | API Gateway (HTTP) | Valida JWT, autoriza por scope, CORS          |
| Backend         | Java 21 + Spring Boot 3.3 | ECS Fargate        | Resource Server, CRUD de productos            |
| Base de datos   | PostgreSQL 16             | RDS                | Persistencia                                  |
| Registro imagen | Docker                    | ECR                | Almacena la imagen del backend                |
| IaC             | Terraform ~5.0            | —                  | Define toda la infraestructura                |

---

## Seguridad: roles y scopes

| Usuario | Grupo    | Scopes                          |
|---------|----------|---------------------------------|
| Admin   | editores | productos/read, productos/write |
| Normal  | lectores | productos/read                  |

Una **Lambda Pre-Token Generation** lee el grupo del usuario e inyecta los scopes
en el access token. El API Gateway autoriza cada ruta según el scope:

| Petición                          | Respuesta                              |
|-----------------------------------|----------------------------------------|
| `GET /productos` sin token        | **401** (no hay credencial)            |
| `GET /productos` con token        | **200** (tiene `productos/read`)       |
| `POST /productos` usuario normal  | **403** (falta `productos/write`)      |
| `POST /productos` admin           | **200/201** (tiene `productos/write`)  |

---

## Estructura del proyecto

```
proyecto/
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
│   │   ├── InfoController.java       endpoint público de metadatos /info
│   │   ├── SecurityConfig.java       Resource Server + validación JWT
│   │   └── DataSeeder.java           productos iniciales
│   ├── Dockerfile                compila con Maven y corre el jar (linux/amd64)
│   └── publicar-ecs.sh           build + push a ECR + redeploy ECS
├── terraform/                    Infraestructura como código
│   ├── cognito.tf                User Pool, cliente SPA, grupos, resource server
│   ├── lambda.tf                 Lambda Pre-Token Generation
│   ├── apigateway.tf             HTTP API, JWT Authorizer, rutas con scopes
│   ├── ecs.tf                    ECR, cluster, task definition, servicio Fargate
│   ├── rds.tf                    PostgreSQL
│   └── amplify.tf                hosting del frontend
└── .github/workflows/            pipelines de CI/CD
```

---

## Endpoints de la API

| Método | Ruta          | Scope requerido   | Descripción           |
|--------|---------------|-------------------|-----------------------|
| GET    | `/productos`  | `productos/read`  | Lista los productos   |
| POST   | `/productos`  | `productos/write` | Crea un producto      |
| GET    | `/info`       | público           | Metadatos del servicio |
| GET    | `/actuator/health` | público      | Health check de ECS   |

---

## Requisitos previos

- Node.js ≥ 22
- Java 21 + Maven
- Docker Desktop (para construir la imagen del backend)
- Terraform ≥ 1.5
- AWS CLI configurado (región `us-east-1`)

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
```

---

## CI/CD

Workflows de GitHub Actions en `.github/workflows/`:

| Pipeline              | Disparador                          | Qué hace                                  |
|-----------------------|-------------------------------------|-------------------------------------------|
| `ci.yml`              | push a `develop`, PR a `main`       | Compila backend y frontend                |
| `frontend-build.yml`  | push a `frontend/**`, PR a `main`   | `npm install` + `npm run build`           |
| `frontend-deploy.yml` | manual                              | build + publicar en Amplify               |
| `backend-build.yml`   | push a `backend/**`, PR a `main`    | `mvn clean package`                       |
| `backend-deploy.yml`  | manual                              | build imagen + push ECR + redeploy ECS    |

Los pipelines de despliegue requieren los secrets `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN` en el repositorio.

---

## Persistencia local

Si no se definen las variables de conexión a RDS, el backend usa H2 en memoria
como fallback, lo que permite levantarlo en local sin base de datos externa.
