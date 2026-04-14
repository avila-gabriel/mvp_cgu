FROM docker.io/erlang:28-alpine

RUN apk add --no-cache netcat-openbsd

WORKDIR /app

COPY server/build/erlang-shipment/ /app/

EXPOSE 4000

CMD ["sh", "/app/entrypoint.sh"]
