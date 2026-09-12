# Guía de contribución

Convenciones para trabajar sobre **Pedidos360** de forma colaborativa, trazable
y ordenada. Cubre estrategia de ramificación, naming de ramas, mensajes de
commit, estructura de carpetas, flujos de merge, estrategias de revisión y
control de versiones.

---

## 1. Estrategia de ramificación: GitFlow

El repositorio usa **GitFlow**: ramas de larga vida (`main` y `develop`) más
ramas de apoyo de vida corta (`feature/*`, `hotfix/*`, `release/*`).

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

## 8. Resumen del ciclo de vida de un cambio

1. Se crea `feature/*` desde `develop`.
2. Se trabaja con commits `feat:` / `fix:` pequeños y claros.
3. Se abre PR hacia `develop`; la **acción de CI compila** front y back.
4. Un compañero **revisa y aprueba**; se hace merge.
5. Cuando `develop` está listo, PR `develop -> main` (nueva versión, con tag).
6. Ante un bug en producción, `hotfix/*` desde `main`, PR a `main` y se porta a
   `develop`.
