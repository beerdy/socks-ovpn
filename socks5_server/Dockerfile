ARG GOLANG_VERSION="1.19.1"

FROM golang:$GOLANG_VERSION-alpine
RUN apk --no-cache add tzdata bash
WORKDIR /go/src/github.com/serjs/socks5
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-s' -o ./socks5

ENTRYPOINT [ "/go/src/github.com/serjs/socks5/entrypoint.sh" ]
