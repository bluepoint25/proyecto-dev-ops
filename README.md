# Pedidos360 — DSY1107 Desarrollo Cloud Native I (EP1)

Sistema FullStack seguro desplegado en AWS. Un frontend en **React** se autentica
contra **AWS Cognito** (IDaaS) mediante **OAuth2 Authorization Code + PKCE**, y
consume un backend **Spring Boot** protegido por un **API Gateway con JWT
Authorizer** y autorización por scopes. El backend corre en **ECS Fargate** y
persiste los datos en **RDS PostgreSQL**.

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

Cuatro workflows de GitHub Actions en `.github/workflows/`:

| Pipeline               | Disparador           | Qué hace                                   |
|------------------------|----------------------|--------------------------------------------|
| `frontend-build.yml`   | push a `frontend/**` | `npm install` + `npm run build`            |
| `frontend-deploy.yml`  | manual               | build + publicar en Amplify                |
| `backend-build.yml`    | push a `backend/**`  | `mvn clean package` (compila y prueba)     |
| `backend-deploy.yml`   | manual               | build imagen + push ECR + redeploy ECS     |

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
