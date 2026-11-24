# syntax=docker/dockerfile:1

# Build on the native platform and cross-compile for the target platform,
# so multi-arch images don't need emulation.
FROM --platform=$BUILDPLATFORM golang:1.27-trixie AS builder
ARG TARGETOS
ARG TARGETARCH
ARG VERSION=dev

WORKDIR /src
COPY . .

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" -o /out/zipstreamer .

# Use the official Debian slim image for a lean production container.
# https://hub.docker.com/_/debian
# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
FROM debian:trixie-slim

# CA certificates for fetching files over https, taken from the builder image
# (avoids apt-get and keeps the image small).
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Copy the binary to the production image from the builder stage.
COPY --from=builder /out/zipstreamer /zipstreamer

# Expose port - shouldn't override PORT env when using docker as server will bind to unexposed port. 
# Instead map exposed port 4008 to desired port when running. 
# Example to bind to port 80 (assuming image named docker-zs) `docker run -p 127.0.0.1:80:4008/tcp docker-zs`
ENV PORT=4008
EXPOSE 4008

CMD ["/zipstreamer"]
