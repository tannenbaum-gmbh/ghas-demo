FROM golang:1.22-bookworm AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=1 go build -o /out/gallery-service ./main.go

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /out/gallery-service ./gallery-service
COPY config.json ./config.json

EXPOSE 8081

ENV GALLERY_HOST=0.0.0.0

CMD ["./gallery-service", "/app/config.json"]
