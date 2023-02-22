#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Generate secrets for Nginx.

NGINX_SSL_CERTIFICATE_CRT_PATH=./docker/nginx/volumes/ssl_certificate.crt
NGINX_SSL_CERTIFICATE_KEY_PATH=./docker/nginx/volumes/ssl_certificate_key.key

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$NGINX_SSL_CERTIFICATE_KEY_PATH" -out "$NGINX_SSL_CERTIFICATE_CRT_PATH" -batch

# Initialize Git submodules.

git submodule update --init --recursive
