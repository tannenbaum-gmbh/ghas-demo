FROM eclipse-temurin:11-jre

WORKDIR /app

ARG JAR_FILE=target/storage-service-*.jar
COPY ${JAR_FILE} ./storage-service.jar

EXPOSE 8082

CMD ["java", "-jar", "/app/storage-service.jar"]
