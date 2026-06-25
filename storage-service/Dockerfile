FROM eclipse-temurin:17-jre

WORKDIR /app

COPY target/storage-service-0.0.1-SNAPSHOT.jar ./storage-service.jar

EXPOSE 8082

CMD ["java", "-jar", "/app/storage-service.jar"]
