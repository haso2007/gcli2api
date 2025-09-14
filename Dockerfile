# --- STAGE 1: Build the Go application ---
FROM golang:1.22-alpine AS builder-go

# 可按需覆盖：--build-arg GOPROXY=https://goproxy.cn,direct
ARG GOPROXY=https://goproxy.cn,direct
# 默认使用官方 sumdb；若仍超时，可在构建时传 --build-arg GOSUMDB=off
ARG GOSUMDB=sum.golang.org

ENV GOPROXY=$GOPROXY
ENV GOSUMDB=$GOSUMDB

WORKDIR /build

# 证书（避免 https 报错）
RUN apk add --no-cache ca-certificates && update-ca-certificates

COPY golang/go.mod golang/go.sum ./
# 先设置 go env 再下载依赖
RUN go env -w GOPROXY=$GOPROXY GOSUMDB=$GOSUMDB && go mod download

COPY golang/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags "-w -s" -o go_app_binary main.go

# --- STAGE 2: Build the final Python application image (最终修正阶段) ---
FROM python:3.11-bullseye
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libxml2-dev \
    libxslt-dev \
    libmaxminddb-dev \
    libyaml-dev \
    supervisor \
    xvfb \
    git \
    libgtk-3-0 \
    libasound2 \
    libdbus-glib-1-2 \
    libxt6 \
    && rm -rf /var/lib/apt/lists/*
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY camoufox-py/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt
RUN camoufox fetch
COPY --from=builder-go /build/go_app_binary /app/go_app_binary
COPY camoufox-py/browser /app/browser
COPY camoufox-py/utils /app/utils
COPY camoufox-py/run_camoufox.py /app/run_camoufox.py
EXPOSE 5345
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
