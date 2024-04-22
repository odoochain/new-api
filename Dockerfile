FROM node:18 as builder

WORKDIR /build
COPY web/package.json .
RUN npm install
COPY ./web .
COPY ./VERSION .
RUN DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat VERSION) npm run build

FROM golang:1.20-alpine AS builder2

ENV GO111MODULE=on \
    CGO_ENABLED=1 \
    GOOS=linux
# Set go proxy to https://goproxy.cn (open for vps in China Mainland)
#RUN go env -w GOPROXY=https://goproxy.cn,direct
# 国内源
RUN echo http://mirrors.aliyun.com/alpine/v3.19/main/ > /etc/apk/repositories

WORKDIR /build
ADD go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=builder /build/build ./web/build
RUN go build -ldflags "-s -w -X 'one-api/common.Version=$(cat VERSION)' -extldflags '-static'" -o one-api

FROM alpine

RUN apk update \
    && apk upgrade \
    && apk add --no-cache ca-certificates tzdata bash \
    && update-ca-certificates 2>/dev/null || true

COPY --from=builder2 /build/one-api /
EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/one-api"]
