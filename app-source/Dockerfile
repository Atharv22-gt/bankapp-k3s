# Stage 1: build the jar with Maven (no need to install Maven on your host)
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -B package -DskipTests

# Stage 2: slim runtime image
FROM eclipse-temurin:17-jdk-alpine
EXPOSE 8080
ENV APP_HOME /usr/src/app
COPY --from=build /build/target/*.jar $APP_HOME/app.jar
WORKDIR $APP_HOME
CMD ["java", "-jar", "app.jar"]
