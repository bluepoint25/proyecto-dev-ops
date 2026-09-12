# Informe Técnico — Pedidos360

**Asignatura:** DSY1107 — Desarrollo Cloud Native I
**Evaluación:** EP1 (Encargo)
**Sistema:** Pedidos360 — aplicación FullStack segura desplegada en AWS
**Repositorio:** https://github.com/bluepoint25/Dsy1107-EA1

---

## 1. Resumen ejecutivo

Pedidos360 es un sistema de gestión de productos que demuestra una arquitectura
cloud native segura. Un frontend en React se autentica contra AWS Cognito usando
el flujo OAuth2 **Authorization Code + PKCE**, y consume un backend Spring Boot
que está protegido por un **API Gateway con JWT Authorizer**. La autorización es
granular por operación: un usuario administrador puede crear productos, mientras
que un usuario normal solo puede consultarlos. El backend persiste los datos en
una base de datos **PostgreSQL en RDS** y corre en contenedores sobre **ECS Fargate**.

El sistema completo está descrito como Infraestructura como Código (Terraform) y
cuenta con cuatro pipelines de CI/CD en GitHub Actions.

---

## 2. Arquitectura general

```
   Usuario (navegador)
        │
        ▼
   Frontend React ── AWS Amplify (hosting HTTPS)
        │
        │  1. Login OAuth2 + PKCE
        ▼
   AWS Cognito (IDaaS) ──── Lambda Pre-Token Generation
        │  emite JWT              (grupo del usuario → scope)
        │
        │  2. Authorization: Bearer <access_token>
        ▼
   AWS API Gateway (HTTP API)
        │  valida firma, issuer, audiencia, expiración y SCOPE
        │  401 si no hay token · 403 si falta el scope
        ▼
   Backend Spring Boot (ECS Fargate)
        │  Resource Server: revalida el JWT (defensa en profundidad)
        ▼
   RDS PostgreSQL (persistencia de productos)
```

La seguridad se aplica en el **borde** (API Gateway), de modo que el backend
recibe peticiones ya validadas. Aun así, el backend revalida el token como
segunda capa de defensa.

---

## 3. Componentes y tecnologías

| Componente     | Tecnología                | Servicio AWS         | Rol                                          |
|----------------|---------------------------|----------------------|----------------------------------------------|
| Frontend       | React 18 + Vite           | Amplify Hosting      | Interfaz, login OAuth2/PKCE, consumo de API   |
| IDaaS          | —                         | Cognito User Pool    | Autenticación, emisión de tokens JWT          |
| Puente permisos| Node.js 20                | Lambda               | Inyecta scopes en el token según el grupo     |
| API Manager    | —                         | API Gateway (HTTP)   | Valida JWT, autoriza por scope, CORS          |
| Backend        | Java 21 + Spring Boot 3.3 | ECS Fargate          | Resource Server, CRUD de productos            |
| Base de datos  | PostgreSQL 16             | RDS                  | Persistencia                                  |
| Registro imagen| Docker                    | ECR                  | Almacena la imagen del backend                |
| IaC            | Terraform ~5.0            | —                    | Define toda la infraestructura                |
| CI/CD          | GitHub Actions            | —                    | 4 pipelines de compilación y despliegue       |

---

## 4. Frontend (React + Vite)

Ubicación: `frontend/`

### 4.1 Estructura

```
frontend/
├── index.html
├── vite.config.js        puerto 5173 fijo (strictPort)
├── package.json
└── src/
    ├── main.jsx          punto de entrada React
    ├── App.jsx           pantalla, tabla de productos, lógica de rol
    ├── auth.js           flujo OAuth2 + PKCE + manejo de tokens
    ├── api.js            llamadas al API Gateway
    └── index.css         estilos
```

### 4.2 `auth.js` — el corazón de la autenticación

Implementa el flujo **Authorization Code + PKCE** manualmente (sin librería), lo
que evidencia el protocolo paso a paso:

- **PKCE:** genera un `code_verifier` aleatorio de 32 bytes y su `code_challenge`
  (SHA-256 en base64url). El verifier nunca viaja en la primera petición; solo
  el challenge. Esto protege el flujo aunque un tercero intercepte el `code`.
- **`login()`:** guarda `verifier` y `state` en `sessionStorage` y redirige al
  Hosted UI de Cognito (`/oauth2/authorize`) con `client_id`, `redirect_uri`,
  `scope`, `state` y `code_challenge`.
- **`procesarRetorno()`:** al volver con `?code=`, valida el `state` (defensa
  CSRF), canjea el `code` por tokens en `/oauth2/token` enviando el
  `code_verifier`, y guarda `access_token` / `id_token` / `refresh_token`.
- **`getRol()`:** lee el claim `cognito:groups` del ID Token. Si el usuario está
  en el grupo `editores` es administrador; si no, es usuario normal.
- **`logout()`:** limpia los tokens locales y llama a `/logout` de Cognito para
  cerrar la sesión SSO.

Los scopes solicitados son `openid email profile productos/read productos/write`.

### 4.3 `api.js` — consumo del backend

Dos funciones que llaman al API Gateway con el `access_token` en la cabecera
`Authorization: Bearer`:

- `getProductos()` → `GET /productos`
- `crearProducto(producto)` → `POST /productos`

### 4.4 `App.jsx` — interfaz y control de rol

- Muestra la tabla de productos obtenidos del backend.
- Si el rol es `admin`, renderiza el formulario "Agregar producto"; si es usuario
  normal, muestra el mensaje "Solo los administradores pueden agregar productos".
- Usa un guard con `useRef` para evitar que React StrictMode procese el `code`
  dos veces (lo que causaba el error `invalid_grant`).

---

## 5. IDaaS y autorización por scopes (Cognito + Lambda)

Ubicación: `terraform/cognito.tf`, `terraform/lambda.tf`, `terraform/lambda/index.mjs`

### 5.1 El problema que resuelve

Cognito no concede scopes por usuario: el techo de scopes lo pone el app client
y es idéntico para todos. El permiso por persona vive en los **grupos**. Falta
un puente que conecte "grupo del usuario" con "scope en el token".

### 5.2 La solución (guía 1.3.11)

```
grupo del usuario  →  Lambda Pre-Token  →  claim scope  →  authorization_scopes
   (el permiso)        (el puente)         (el transporte)     (el guard en API GW)
```

- **Resource Server** (`aws_cognito_resource_server`): declara que existen los
  scopes `productos/read` y `productos/write`.
- **Grupos:**
  - `editores` → recibe `productos/read` + `productos/write` (el admin está aquí).
  - `lectores` → recibe solo `productos/read` (el usuario normal está aquí).
- **Lambda `user-token-ms`** (trigger *Pre Token Generation V2_0*): lee los grupos
  del usuario e inyecta los scopes correspondientes en el **access token** antes
  de que Cognito lo firme. Código en `lambda/index.mjs`:

  ```js
  const SCOPES_POR_GRUPO = {
    editores: ['productos/read', 'productos/write'],
    lectores: ['productos/read'],
  }
  ```

- **`aws_lambda_permission`**: autoriza a Cognito a invocar la Lambda. Sin este
  permiso, el login falla silenciosamente.

### 5.3 Usuarios de prueba

| Usuario | Email                   | Grupo    | Scopes                         |
|---------|-------------------------|----------|--------------------------------|
| Admin   | admin@pedidos360.cl     | editores | productos/read, productos/write|
| Normal  | usuario@pedidos360.cl   | lectores | productos/read                 |

Contraseña de ambos: `Pedidos2025!` (solo para laboratorio).

---

## 6. API Gateway (el guardián)

Ubicación: `terraform/apigateway.tf`

- **HTTP API** con configuración CORS que permite `localhost:5173` (desarrollo) y
  la URL de Amplify (producción).
- **JWT Authorizer** apuntando al issuer del User Pool de Cognito. Descarga las
  claves públicas (JWKS) una vez y verifica la firma de cada token localmente,
  sin volver a consultar a Cognito en cada petición.
- **Rutas con autorización por scope:**
  - `GET /productos` → exige `productos/read` (ambos usuarios).
  - `POST /productos` → exige `productos/write` (solo admin).
- **Integraciones HTTP_PROXY** que reenvían al backend en ECS por su IP pública
  (puerto 8080). Se usa `ignore_changes` en la URI porque la IP cambia en cada
  despliegue y la reapunta el script de publicación.

Comportamiento de seguridad verificado:

| Petición                        | Respuesta | Motivo                              |
|---------------------------------|-----------|-------------------------------------|
| GET /productos sin token        | 401       | No hay credencial                   |
| GET /productos con token válido | 200       | Tiene scope productos/read          |
| POST /productos (usuario normal)| 403       | Falta scope productos/write         |
| POST /productos (admin)         | 200/201   | Tiene scope productos/write         |

---

## 7. Backend (Spring Boot en ECS Fargate)

Ubicación: `backend/`

### 7.1 Estructura de clases

```
backend/src/main/java/cl/pedidos360/backend/
├── BackendApplication.java   arranque de Spring Boot
├── Producto.java             entidad JPA (id, nombre, precio, stock)
├── ProductoRepository.java   repositorio JPA (extends JpaRepository)
├── ProductoController.java   endpoints REST GET/POST /productos
├── SecurityConfig.java       Resource Server + validación JWT + CORS
└── DataSeeder.java           inserta 3 productos iniciales
```

### 7.2 Seguridad (guía 1.3.3)

`SecurityConfig.java` configura el backend como **OAuth2 Resource Server**:

- Valida el JWT emitido por Cognito usando el `issuer-uri`.
- `@EnableMethodSecurity` habilita `@PreAuthorize` en el controller.
- Convierte el claim `scope` del token en authorities con prefijo `SCOPE_`.
- El endpoint `/actuator/health` es público (para el health check de ECS); todo
  lo demás exige token.

`ProductoController.java` refuerza la autorización con anotaciones:

```java
@GetMapping  @PreAuthorize("hasAuthority('SCOPE_productos/read')")
@PostMapping @PreAuthorize("hasAuthority('SCOPE_productos/write')")
```

Esto es defensa en profundidad: aunque el API Gateway ya filtra por scope, el
backend vuelve a validar.

### 7.3 Persistencia

`application.properties` configura la conexión a PostgreSQL mediante variables de
entorno inyectadas por ECS (`SPRING_DATASOURCE_URL`, `USERNAME`, `PASSWORD`). Si
no existen (ejecución local), usa H2 en memoria como fallback. La URL de RDS
incluye `sslmode=require`.

### 7.4 Contenedorización (guía 1.3.9)

`Dockerfile` multi-etapa:
1. Etapa build: usa `maven:3.9-eclipse-temurin-21`, compila el jar.
2. Etapa final: usa `eclipse-temurin:21-jre`, copia el jar, instala `curl` para
   el health check.

La imagen se construye con `--platform linux/amd64` (obligatorio: Fargate corre
x86_64 y evita el error `exec format error` en máquinas ARM).

---

## 8. Base de datos (RDS PostgreSQL)

Ubicación: `terraform/rds.tf`

- Instancia `db.t3.micro`, PostgreSQL 16.9, 20 GB.
- Security group que permite el puerto 5432.
- Subnet group con las subredes públicas de la VPC por defecto.
- `skip_final_snapshot = true` (entorno de laboratorio).

---

## 9. ECS Fargate

Ubicación: `terraform/ecs.tf`

- **ECR:** registro privado donde vive la imagen del backend.
- **CloudWatch Log Group:** recibe el stdout del contenedor (retención 7 días).
- **Security Group:** abre el puerto 8080 (el API Gateway llama por internet).
- **Cluster:** en Fargate es solo un nombre lógico.
- **Task Definition:** la "receta" — imagen, 512 CPU / 1024 MB memoria,
  `X86_64`, variables de entorno (conexión a RDS), health check con
  `curl /actuator/health` y `startPeriod` de 60s para dar tiempo a Spring Boot.
- **Service:** mantiene 1 task viva, con IP pública asignada. Usa
  `ignore_changes = [task_definition]` para que el despliegue de la imagen no sea
  revertido por Terraform.

Se usa `LabRole` como rol de ejecución (AWS Academy no permite crear roles IAM).

---

## 10. Hosting del Frontend (AWS Amplify)

Ubicación: `terraform/amplify.tf`

- `aws_amplify_app` con `platform = "WEB"` (sitio estático).
- Regla `custom_rule` que redirige cualquier ruta no-archivo a `index.html`
  (necesario para una SPA; sin ella, cualquier ruta distinta de `/` da 404).
- `aws_amplify_branch` para la rama `main`.
- Despliegue manual por zip (create-deployment → PUT del zip → start-deployment),
  ya que el curso no versiona el código de config.

URL pública: `https://main.<app_id>.amplifyapp.com`

---

## 11. Infraestructura como Código (Terraform)

Ubicación: `terraform/`

| Archivo         | Qué define                                                    |
|-----------------|---------------------------------------------------------------|
| `versions.tf`   | Versión de Terraform y proveedor AWS                          |
| `variables.tf`  | Variables: grupo, emails y contraseñas de usuarios            |
| `cognito.tf`    | User Pool, cliente SPA, dominio, grupos, resource server      |
| `lambda.tf`     | Lambda Pre-Token Generation y su permiso                      |
| `apigateway.tf` | HTTP API, JWT Authorizer, integraciones y rutas               |
| `ecs.tf`        | ECR, log group, cluster, task definition, servicio            |
| `rds.tf`        | PostgreSQL, security group, subnet group                      |
| `amplify.tf`    | App y rama de Amplify                                         |
| `outputs.tf`    | Valores de salida (URLs, IDs)                                 |

El estado (`.tfstate`) y la carpeta `.terraform/` están en `.gitignore` y no se
versionan, según la buena práctica de la guía 1.1.2b.

---

## 12. Pipelines CI/CD (GitHub Actions)

Ubicación: `.github/workflows/` — cuatro pipelines según pide la evaluación:

| Pipeline               | Disparador           | Qué hace                                        |
|------------------------|----------------------|-------------------------------------------------|
| `frontend-build.yml`   | push a `frontend/**` | `npm install` + `npm run build`                 |
| `frontend-deploy.yml`  | manual               | build + publicar en Amplify (zip)               |
| `backend-build.yml`    | push a `backend/**`  | `mvn clean package` (compila y prueba)          |
| `backend-deploy.yml`   | manual               | build imagen + push ECR + redeploy ECS          |

Los pipelines de despliegue requieren los secrets `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN` configurados en el repositorio.
Como las credenciales de AWS Academy son temporales, deben renovarse cuando
expiran.

---

## 13. Flujo completo de una petición (ejemplo: admin agrega un producto)

1. El admin inicia sesión → el frontend redirige a Cognito con PKCE.
2. Cognito autentica y, mediante la Lambda, emite un access token con scopes
   `productos/read productos/write`.
3. El frontend envía `POST /productos` con `Authorization: Bearer <token>`.
4. El API Gateway valida la firma del token y comprueba que tiene el scope
   `productos/write`. Como sí lo tiene, reenvía la petición al backend.
5. El backend (Spring Boot) revalida el token, ejecuta `@PreAuthorize` y guarda
   el producto en RDS PostgreSQL.
6. La respuesta vuelve al frontend, que recarga la lista.

Si un usuario normal intentara el mismo POST, el API Gateway lo detendría con un
**403 Forbidden** porque su token no trae el scope `productos/write`.

---

## 14. Cumplimiento de la pauta de evaluación

| Indicador de la EP1                                         | Estado |
|-------------------------------------------------------------|--------|
| OIDC con React y obtención de todos los tokens              | ✅     |
| Inicio y cierre de sesión funcionando                       | ✅     |
| Lectura de roles/scopes desde los claims                    | ✅     |
| Backend valida issuer, audience, firma y vigencia del token | ✅     |
| Autorización por rol (403 cuando corresponde)               | ✅     |
| Integración con base de datos cloud (RDS)                   | ✅     |
| Cuatro pipelines (build y deploy de front y back)           | ✅     |
| `.gitignore` por tecnología                                 | ✅     |
| Entrega vía GitHub                                          | ✅     |

---

## 15. Credenciales y datos de referencia

| Recurso          | Valor                                              |
|------------------|----------------------------------------------------|
| Usuario admin    | admin@pedidos360.cl / Pedidos2025!                 |
| Usuario normal   | usuario@pedidos360.cl / Pedidos2025!               |
| Región AWS       | us-east-1                                           |
| Repositorio      | https://github.com/bluepoint25/Dsy1107-EA1         |

> Nota de seguridad: las contraseñas por defecto y las credenciales del lab son
> exclusivamente para el entorno de evaluación. En un entorno real se usarían
> AWS Secrets Manager y contraseñas gestionadas fuera del código.
