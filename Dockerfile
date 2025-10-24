+ docker build -t yigittq/jenkins-demo-api:48 -t yigittq/jenkins-demo-api:latest .
#0 building with "default" instance using docker driver
#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 672B 0.0s done
#1 DONE 0.1s
#2 [internal] load metadata for docker.io/library/python:3.11-slim
#2 ...
#3 [auth] library/python:pull token for registry-1.docker.io
#3 DONE 0.0s
#2 [internal] load metadata for docker.io/library/python:3.11-slim
#2 DONE 0.4s
#4 [internal] load .dockerignore
#4 transferring context: 403B done
#4 DONE 0.0s
#5 [1/6] FROM docker.io/library/python:3.11-slim@sha256:8eb5fc663972b871c528fef04be4eaa9ab8ab4539a5316c4b8c133771214a617
#5 resolve docker.io/library/python:3.11-slim@sha256:8eb5fc663972b871c528fef04be4eaa9ab8ab4539a5316c4b8c133771214a617 0.0s done
#5 DONE 0.0s
#6 [2/6] WORKDIR /app
#6 CACHED
#7 [internal] load build context
#7 transferring context: 14.86kB 0.0s done
#7 DONE 0.1s
#8 [3/6] RUN curl -LsSf https://astral.sh/uv/install.sh | sh
curl: not found
#8 DONE 1.1s
#9 [4/6] COPY requirements.txt requirements.txt
#9 DONE 0.1s
#10 [5/6] RUN uv pip install --no-cache --system -r requirements.txt
#10 0.884 /bin/sh: 1: uv: not found
#10 ERROR: process "/bin/sh -c uv pip install --no-cache --system -r requirements.txt" did not complete successfully: exit code: 127
------
 > [5/6] RUN uv pip install --no-cache --system -r requirements.txt:
uv: not found
------
Dockerfile:12
--------------------
  10 |     COPY requirements.txt requirements.txt
  11 |     # uv ile bağımlılıklar kuruluyor
  12 | >>> RUN uv pip install --no-cache --system -r requirements.txt
  13 |     # --system: Sanal ortam oluşturmadan doğrudan sisteme kurar (Docker imajları için yaygın)
  14 |     # --no-cache: Docker katmanlarını küçük tutar
--------------------
ERROR: failed to solve: process "/bin/sh -c uv pip install --no-cache --system -r requirements.txt" did not complete successfully: exit code: 127
script returned exit code 1