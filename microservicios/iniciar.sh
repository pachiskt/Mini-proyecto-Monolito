#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="microservicios"
SERVICES=("usuarios" "productos" "pedidos")
LOCAL_PORTS=(3101 3102 3103)
TARGET_PORTS=(3001 3002 3003)

stop_forwarders() {
  local service pidfile pid
  for service in "${SERVICES[@]}"; do
    pidfile="/tmp/minikube-${service}-port-forward.pid"
    if [ -f "$pidfile" ]; then
      pid="$(cat "$pidfile" 2>/dev/null || true)"
      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
      fi
      rm -f "$pidfile"
    fi
  done
}

start_forwarder() {
  local service="$1"
  local local_port="$2"
  local target_port="$3"
  local pidfile="/tmp/minikube-${service}-port-forward.pid"

  (
    child=""
    stop_child() {
      trap - TERM INT
      if [ -n "$child" ]; then
        kill -TERM "$child" 2>/dev/null || true
        wait "$child" 2>/dev/null || true
      fi
      exit 0
    }
    trap stop_child TERM INT

    while true; do
      kubectl port-forward --address 127.0.0.1 -n "$NAMESPACE" "svc/$service" "${local_port}:${target_port}" &
      child=$!
      wait "$child" || true
      child=""
      sleep 2
    done
  ) >"/tmp/${service}-port-forward.log" 2>&1 &

  echo "$!" >"$pidfile"
}

case "${1:-start}" in
  start)
    command -v minikube >/dev/null || { echo "Error: falta instalar Minikube."; exit 1; }
    command -v kubectl >/dev/null || { echo "Error: falta instalar kubectl."; exit 1; }

    if ! minikube status >/dev/null 2>&1; then
      echo "Iniciando Minikube..."
      minikube start --driver=docker
    fi

    kubectl get namespace "$NAMESPACE" >/dev/null

    for service in "${SERVICES[@]}"; do
      kubectl get service "$service" -n "$NAMESPACE" >/dev/null
    done

    echo "Esperando a que los pods estén listos..."
    if ! kubectl wait --for=condition=Ready pods --all -n "$NAMESPACE" --timeout=180s; then
      echo "Error, hay pods que no están listos."
      echo "Comprueba con: kubectl get pods -n $NAMESPACE"
      exit 1
    fi

    stop_forwarders

    echo "Abriendo accesos locales..."
    for i in "${!SERVICES[@]}"; do
      start_forwarder "${SERVICES[$i]}" "${LOCAL_PORTS[$i]}" "${TARGET_PORTS[$i]}"
    done

    for intento in {1..15}; do
      disponibles=0
      for i in "${!SERVICES[@]}"; do
        if grep -Fq "Forwarding from 127.0.0.1:${LOCAL_PORTS[$i]}" "/tmp/${SERVICES[$i]}-port-forward.log" 2>/dev/null; then
          disponibles=$((disponibles + 1))
        fi
      done
      [[ "$disponibles" -eq 3 ]] && break
      sleep 1
    done

    for i in "${!SERVICES[@]}"; do
      service="${SERVICES[$i]}"
      port="${LOCAL_PORTS[$i]}"
      if grep -Fq "Forwarding from 127.0.0.1:$port" "/tmp/${service}-port-forward.log" 2>/dev/null; then
        echo "$service: http://localhost:$port"
      else
        echo "Error en $service. Revisa /tmp/${service}-port-forward.log"
      fi
    done
    ;;

  stop)
    stop_forwarders
    if minikube status >/dev/null 2>&1; then
      minikube stop
    else
      echo "Minikube ya estaba detenido."
    fi
    ;;

  *)
    echo "Uso: $0 [start|stop]"
    exit 2
    ;;
esac
