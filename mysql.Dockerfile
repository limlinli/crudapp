FROM mysql:8.0
COPY ./dump/lna.sql /docker-entrypoint-initdb.d/init.sql
