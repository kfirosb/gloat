FROM adoptopenjdk/openjdk13:debianslim

# Install dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates

WORKDIR /usr/tsunami/repos

# Clone the plugins repo
RUN git clone --depth 1 "https://github.com/google/tsunami-security-scanner-plugins"

# Build plugins
WORKDIR /usr/tsunami/repos/tsunami-security-scanner-plugins/google
RUN chmod +x build_all.sh \
    && ./build_all.sh

RUN mkdir /usr/tsunami/plugins \
    && cp build/plugins/*.jar /usr/tsunami/plugins

# Compile the Tsunami scanner
WORKDIR /usr/repos
RUN git clone --depth 1 "https://github.com/google/tsunami-security-scanner"
WORKDIR /usr/repos/tsunami-security-scanner
RUN ./gradlew shadowJar \
    && cp $(find "./" -name 'tsunami-main-*-cli.jar') /usr/tsunami/tsunami.jar \
    && cp ./tsunami.yaml /usr/tsunami

# Stage 2: Release
FROM adoptopenjdk/openjdk13:debianslim-jre

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends nmap ncrack ca-certificates \
    && apt-get clean \
    && mkdir logs/

WORKDIR /usr/tsunami

COPY --from=0 /usr/tsunami /usr/tsunami
COPY ./scripts/start.sh /mnt/tsunami-config/start.sh

ENTRYPOINT  ["/bin/sh", "-c", "chmod +x /mnt/tsunami-config/start.sh && /mnt/tsunami-config/start.sh"]