FROM mysql:8.0
COPY ./dump/lena.sql /docker-entrypoint-initdb.d/init.sql
