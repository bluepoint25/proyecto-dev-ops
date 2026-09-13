# Guía de contribución

Convenciones para trabajar sobre **Pedidos360** de forma colaborativa, trazable
y ordenada. Cubre estrategia de ramificación, naming de ramas, mensajes de
commit, estructura de carpetas, flujos de merge, estrategias de revisión y
control de versiones.

---

## 1. Estrategia de ramificación

### Modelos considerados

| Modelo               | Idea central                                                                        | Cuándo conviene                                             |
|----------------------|-------------------------------------------------------------------------------------|-------------------------------------------------------------|
| **GitFlow**          | Ramas de larga vida (`main`, `develop`) + ramas de apoyo (`feature/*`, `hotfix/*`, `release/*`). | Versiones planificadas, revisión formal por PR, releases claras. |
| **GitHub Flow**      | Solo `main` + ramas de feature con PR y despliegue continuo.                        | Entrega continua, apps web con despliegues muy frecuentes.  |
| **Trunk-Based Dev.** | Todos integran a un único tronco con commits pequeños y frecuentes, tras feature flags. | Equipos con CI muy maduro y alta frecuencia de integración. |

### Elección: GitFlow

El repositorio usa **GitFlow**: ramas de larga vida (`main` y `develop`) más
ramas de apoyo de vida corta (`feature/*`, `hotfix/*`, `release/*`). Se eligió
porque:

- Separa con claridad lo estable (`main`) de lo que aún se integra (`develop`),
  dando trazabilidad de qué está en producción.
- Cada persona trabaja aislada en su `feature/*` y la integra por Pull Request,
  lo que habilita revisión de código antes del merge.
- Las ramas `hotfix/*` permiten corregir producción sin arrastrar trabajo a
  medio hacer de `develop`.

Trunk-based encaja mejor con integración continua muy madura y despliegues
diarios; GitHub Flow es ideal para entrega continua pura. Para un flujo con
releases planificadas y revisión formal por PR, GitFlow equilibra mejor control,
trazabilidad y colaboración.

### Ramas de larga vida

| Rama      | Propósito                                                            | ¿Recibe merge directo? |
|-----------|---------------------------------------------------------------------|------------------------|
| `main`    | Código estable, listo para producción. Cada merge es una versión.   | No (solo vía PR)       |
| `develop` | Rama de integración. Acumula las features terminadas.               | No (solo vía PR)       |

### Ramas de apoyo (vida corta)

| Prefijo      | Nace de   | Se integra a      | Uso                                        |
|--------------|-----------|-------------------|--------------------------------------------|
| `feature/*`  | `develop` | `develop`         | Nueva funcionalidad                        |
| `hotfix/*`   | `main`    | `main` y `develop`| Corrección urgente en producción           |
| `release/*`  | `develop` | `main` y `develop`| Preparación de una versión (opcional)      |

---

## 2. Naming de ramas

Formato: `<tipo>/<descripcion-corta-en-kebab-case>`

- `feature/health-endpoint`
- `feature/validacion-precio`
- `hotfix/cors-produccion`
- `release/1.1.0`

Reglas:

- Usar solo minúsculas, números y guiones.
- Descripción breve y significativa (qué hace, no cómo).
- Un tema por rama. Ramas pequeñas y de vida corta.

---

## 3. Convención de mensajes de commit

Se usa **Conventional Commits**: `<tipo>(<alcance opcional>): <descripción>`

Tipos permitidos:

| Tipo       | Cuándo usarlo                                             |
|------------|-----------------------------------------------------------|
| `feat`     | Nueva funcionalidad                                       |
| `fix`      | Corrección de un bug                                      |
| `docs`     | Solo documentación                                        |
| `style`    | Formato, sin cambios de lógica                            |
| `refactor` | Reestructuración sin cambiar comportamiento               |
| `test`     | Añadir o corregir pruebas                                 |
| `chore`    | Tareas de mantenimiento, build, dependencias              |
| `ci`       | Cambios en pipelines de CI/CD                             |

Ejemplos:

```
feat(backend): agregar endpoint /actuator/info
fix(frontend): evitar doble canje del code en StrictMode
docs: documentar convenciones de commit y flujo de merge
ci: ejecutar build en push a develop y PR a main
```

Reglas:

- Descripción en imperativo y en minúscula ("agregar", no "agregado").
- Máximo ~72 caracteres en el título; el detalle va en el cuerpo.
- Un commit = un cambio lógico coherente.

---

## 4. Estructura de carpetas

```
proyecto/
├── README.md            documentación técnica del proyecto
├── CONTRIBUTING.md      esta guía de contribución
├── .gitignore           exclusiones a nivel raíz
├── .github/workflows/   pipelines de GitHub Actions (CI/CD)
├── frontend/            aplicación React + Vite
│   └── src/
├── backend/             backend Spring Boot (Java 21)
│   └── src/main/java/…
└── terraform/           infraestructura como código (IaC)
```

Principios:

- Cada componente (frontend, backend, terraform) es autocontenido y tiene su
  propio `.gitignore`.
- Los artefactos generados (`node_modules/`, `target/`, `dist/`, `.terraform/`,
  `*.tfstate`) **no se versionan**.
- La documentación vive en la raíz en formato Markdown.

---

## 5. Flujo de merge

### Feature (funcionalidad nueva)

```
git checkout develop
git pull origin develop
git checkout -b feature/mi-feature
# … trabajo + commits …
git push -u origin feature/mi-feature
# Abrir Pull Request  feature/mi-feature  ->  develop
```

### Hotfix (arreglo urgente en producción)

```
git checkout main
git pull origin main
git checkout -b hotfix/mi-arreglo
# … arreglo + commit …
git push -u origin hotfix/mi-arreglo
# Abrir PR  hotfix/mi-arreglo  ->  main   (y luego portar el fix a develop)
```

### Release a producción

Cuando `develop` acumula features listas, se abre un PR `develop -> main`. El
merge a `main` representa una nueva versión desplegable.

Regla de oro: **nadie hace push directo a `main` ni a `develop`**. Todo cambio
entra por Pull Request para que la acción de CI lo valide y un compañero lo revise.

---

## 6. Estrategia de revisión (Code Review)

- Todo PR requiere **al menos 1 aprobación** de otra persona del equipo.
- El PR no se mergea si la acción de CI (`CI - Integración Continua`) falla.
- El PR debe describir: qué cambia, por qué, y cómo se probó.
- Revisar en bloques pequeños; preferir varios PRs pequeños a uno gigante.
- Comentarios de revisión: concretos, respetuosos y accionables.
- El autor no aprueba su propio PR.
- Tipo de merge recomendado: **merge commit** (`--no-ff`) para conservar la
  trazabilidad del historial de cada rama en el grafo de Git.

---

## 7. Control de versiones

- Versionado semántico **SemVer**: `MAJOR.MINOR.PATCH` (ej. `1.2.0`).
  - `MAJOR`: cambios incompatibles.
  - `MINOR`: nueva funcionalidad compatible.
  - `PATCH`: correcciones compatibles (hotfix).
- Cada merge a `main` se etiqueta con un tag: `git tag -a v1.1.0 -m "…"`.
- El historial se mantiene legible gracias a Conventional Commits (permite
  generar changelogs automáticos).
- No se reescribe el historial de ramas compartidas (`main`, `develop`).

---

## 8. Integración y despliegue continuo (CI/CD)

La automatización vive en `.github/workflows/` y se apoya en **GitHub Actions**.

### Integración continua (CI)

`ci.yml` es la puerta de calidad. Se ejecuta automáticamente en:

- **cada push a `develop`** → valida la integración de cada feature;
- **cada pull request hacia `main`** → valida el candidato a release antes de
  que llegue a producción.

Compila el backend (`mvn clean package`) y el frontend (`npm run build`). Si
alguno falla, la Action queda en rojo y el cambio no debe integrarse. Así ningún
código roto entra a `develop` ni a `main`, sin intervención manual. Los
workflows `backend-build.yml` y `frontend-build.yml` refuerzan esa validación
por componente.

### Despliegue continuo (CD)

Los workflows `backend-deploy.yml` y `frontend-deploy.yml` publican el backend
en ECS y el frontend en Amplify. Se disparan de forma manual (`workflow_dispatch`)
y requieren las credenciales de AWS como secrets del repositorio.

### Rol dentro del proceso CI/CD

- **CI** (build automático en cada push/PR): detecta errores temprano y mantiene
  las ramas principales siempre compilables.
- **CD** (deploy a AWS): lleva lo ya validado al entorno cloud.

En conjunto, la automatización convierte el repositorio en el disparador del
flujo DevOps: un cambio integrado por PR se valida solo y, una vez aprobado,
puede desplegarse de forma reproducible.

---

## 9. Resumen del ciclo de vida de un cambio

1. Se crea `feature/*` desde `develop`.
2. Se trabaja con commits `feat:` / `fix:` pequeños y claros.
3. Se abre PR hacia `develop`; la **acción de CI compila** front y back.
4. Un compañero **revisa y aprueba**; se hace merge.
5. Cuando `develop` está listo, PR `develop -> main` (nueva versión, con tag).
6. Ante un bug en producción, `hotfix/*` desde `main`, PR a `main` y se porta a
   `develop`.
