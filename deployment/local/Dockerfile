#
# Simplified Dockerfile for local development builds (no OTEL agent)
#
FROM eclipse-temurin:21-jre-alpine

ARG JAR

ARG APP_USER=docker
ARG APP_UID=10100

RUN addgroup --system "$APP_USER" && \
    adduser \
      --shell /sbin/nologin \
      --disabled-password \
      --gecos "" \
      --ingroup "$APP_USER" \
      --no-create-home \
      --uid "$APP_UID" \
      "$APP_USER"

USER "$APP_USER"
WORKDIR /app

COPY ${JAR} edc-runtime.jar

HEALTHCHECK --interval=10s --timeout=5s --retries=6 \
  CMD wget --spider --quiet http://localhost:8080/api/check/health || exit 1

ENTRYPOINT ["java", \
     "-Dedc.fs.config=/app/configuration.properties", \
     "-Djava.security.egd=file:/dev/urandom", \
     "-jar", \
     "edc-runtime.jar"]
