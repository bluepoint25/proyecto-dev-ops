# Pedidos360 — DSY1107 Desarrollo Cloud Native I (EFT)

Sistema FullStack seguro desplegado en AWS. Un frontend React se autentica contra
AWS Cognito (IDaaS) mediante OAuth2 Authorization Code + PKCE, y consume un backend
Spring Boot protegido por un API Gateway con JWT Authorizer y autorización por scopes.

## Arquitectura

```
  Usuario
    │
    ▼
  Frontend React (AWS Amplify)  ──login OAuth2/PKCE──►  Cognito (IDaaS)
    │                                                       │
    │  Authorization: Bearer <access_token>                 │ Pre-Token Lambda
    ▼                                                       │ (grupo → scope)
  API Gateway (HTTP API)  ── valida JWT + scope ────────────┘
    │
    ▼
  Backend Spring Boot (ECS Fargate)  ──►  RDS PostgreSQL
```

## Componentes

| Componente   | Tecnología           | Rol                                             |
|--------------|----------------------|-------------------------------------------------|
| Frontend     | React + Vite         | Interfaz, login OAuth2/PKCE, consumo de la API  |
| IDaaS        | AWS Cognito          | Autenticación, emisión de tokens JWT            |
| API Manager  | AWS API Gateway      | Valida JWT, autoriza por scope, CORS            |
| Backend      | Spring Boot (Java 21)| Resource Server, CRUD de productos              |
| Base de datos| RDS PostgreSQL       | Persistencia de productos                       |
| Hosting front| AWS Amplify          | Sitio estático con HTTPS                         |

## Seguridad: roles y scopes

- **Usuario admin** (`admin@pedidos360.cl`) → grupo `editores` → scopes `productos/read` + `productos/write`.
- **Usuario normal** (`usuario@pedidos360.cl`) → grupo `lectores` → scope `productos/read`.

Una **Lambda Pre-Token Generation** lee el grupo del usuario e inyecta los scopes
en el access token. El API Gateway autoriza cada ruta según el scope:

- `GET /productos` exige `productos/read` → ambos usuarios.
- `POST /productos` exige `productos/write` → solo admin (editores). Sin el scope: **403**.
- Sin token: **401**.

## Estructura

```
proyecto/
├── frontend/          React + Vite (auth.js con PKCE, api.js, App.jsx)
├── backend/           Spring Boot (Resource Server + JPA + PostgreSQL)
│   ├── Dockerfile     compila con Maven y corre el jar (linux/amd64)
│   └── publicar-ecs.sh  build + push a ECR + redeploy ECS (guía 1.3.9)
├── terraform/         Infraestructura como código
│   ├── cognito.tf     User Pool, cliente SPA, grupos, resource server
│   ├── lambda.tf      Lambda Pre-Token Generation
│   ├── apigateway.tf  HTTP API, JWT Authorizer, rutas con scopes
│   ├── ecs.tf         ECR, cluster, task definition, servicio Fargate
│   ├── rds.tf         PostgreSQL
│   └── amplify.tf     hosting del frontend
└── .github/workflows/ 4 pipelines CI/CD
```

## Pipelines (CI/CD)

Cuatro workflows de GitHub Actions en `.github/workflows/`:

1. `backend-build.yml` — compila y prueba el backend (Maven).
2. `backend-deploy.yml` — build de imagen Docker, push a ECR, redeploy ECS.
3. `frontend-build.yml` — instala dependencias y compila el frontend.
4. `frontend-deploy.yml` — compila y publica el frontend en Amplify.

Los pipelines de despliegue requieren los secrets `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN` en el repositorio.

## Despliegue manual

```bash
# 1. Infraestructura
cd terraform
terraform init
terraform apply

# 2. Backend (imagen a ECR + ECS)
cd ../backend
./publicar-ecs.sh

# 3. Frontend (build + publicar en Amplify)
cd ../frontend
npm install && npm run build
# luego: create-deployment → PUT del zip → start-deployment (ver guía 1.2.9e)
```

## Credenciales de prueba

| Usuario  | Email                   | Contraseña      | Rol    |
|----------|-------------------------|-----------------|--------|
| Admin    | admin@pedidos360.cl     | Pedidos2025!    | editor |
| Normal   | usuario@pedidos360.cl   | Pedidos2025!    | lector |

> Las contraseñas por defecto son solo para el entorno de laboratorio.
