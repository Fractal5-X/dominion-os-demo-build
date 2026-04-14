FROM eclipse-temurin:17-jdk-jammy

WORKDIR /app

COPY java-site/src /app/src

RUN mkdir -p /app/build/classes \
    && javac -Xlint:all -d /app/build/classes $(find /app/src -name '*.java')

ENV PORT=8090
EXPOSE 8090

ENTRYPOINT ["java", "-XX:+UseG1GC", "-XX:MaxRAMPercentage=70", "-Dfile.encoding=UTF-8", "-cp", "/app/build/classes", "com.dominion.liveops.JavaLiveOpsSite"]
