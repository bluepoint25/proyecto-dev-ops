# ─── Etapa 1: compilar el jar ─────────────────────────────────────────────────
# Las pruebas NO se ejecutan aqui: las corre el job "test" del pipeline antes de
# construir la imagen (la imagen solo se construye si las pruebas pasan).
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests -B

# ─── Etapa 2: imagen final ligera ─────────────────────────────────────────────
FROM eclipse-temurin:21-jre
WORKDIR /app

# Trazabilidad: el pipeline inyecta el commit y la version como etiquetas OCI
ARG GIT_SHA=local
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="pedidos360-backend" \
      org.opencontainers.image.source="https://github.com/bluepoint25/proyecto-dev-ops" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.version="${APP_VERSION}"

# curl para los health checks (ECS, Docker Compose, Kubernetes)
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 app && useradd --system --uid 10001 --gid app --no-create-home app

COPY --from=build --chown=app:app /app/target/backend-*.jar app.jar

# Seguridad: el proceso no corre como root
USER 10001

# Escalabilidad: la JVM respeta los limites de memoria del contenedor
ENV GIT_SHA=${GIT_SHA} APP_VERSION=${APP_VERSION}
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -fsS http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
