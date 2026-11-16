FROM eclipse-temurin:17-jre

WORKDIR /app

RUN useradd --system --create-home appuser

COPY target/*.jar app.jar

USER appuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]