# stripped-keycloak

Keycloak 26.7.2 on Alpine 3.24.1 plus a Temurin musl `jlink` JRE. The official `quay.io/keycloak/keycloak` image is not used. Java is not an apk or RPM package. `apk` is deleted from the final layer.

GitHub Actions builds on public runners (where the Keycloak tarball and Adoptium JDK are reachable) and publishes to GHCR. The Containerfile still pulls Alpine from docker.io. Internal Jenkins and CCE only pull the baked image through Nexus.

## Image contract

| Layer | What it is | What it is not |
| --- | --- | --- |
| Keycloak | Official `keycloak-26.7.2.tar.gz`, SHA256 verified | `quay.io/keycloak/keycloak` |
| Java | Temurin musl JDK, `jlink`'d (21 default, 25 via `JAVA_MAJOR`) | Alpine or RHEL OpenJDK |
| OS | Alpine musl, busybox, certs, tz, zlib, libstdc++, fonts | UBI, bash, findutils, locale pack, apk |
| User | UID 1000, GID 0, `g+rwX` on `/opt/keycloak` | UID 1001 / Bitnami layout |
| Entry | `/opt/keycloak/bin/kc.sh` | Bitnami `entrypoint.sh` |
| Default CMD | `start --optimized` | `start-dev` |

Baked at build time: `KC_DB=postgres`, `KC_HEALTH_ENABLED=true`, `KC_METRICS_ENABLED=true`. Runtime default: `KC_CACHE=local`. TLS is not generated in the image. Mount PEM at `/opt/keycloak/certs/tls.crt` and `tls.key`.

`kc.sh` is POSIX `#!/bin/sh`. Busybox is enough. Compiler modules stay in the jlink set so `kc.sh build` still works. `jdk.jconsole`, `jdk.jshell`, `jdk.javadoc`, `jdk.jlink`, `jdk.jpackage`, `jdk.jdeps`, `jdk.jcmd`, `jdk.jstatd`, `jdk.editpad` are dropped.

## Pins

| Artifact | Version | SHA256 |
| --- | --- | --- |
| [keycloak-26.7.2.tar.gz](https://github.com/keycloak/keycloak/releases/download/26.7.2/keycloak-26.7.2.tar.gz) | 26.7.2 | `4f3ce3b797a9d98998b7f1a6bd5d2b9832100faea66c48988713a9b23eda5c44` |
| Temurin 21 alpine x64 | 21.0.12.1+1 | `bd8824214e42b33333c7f55a039ea078ad6ea6be20d7c5b011c801fb2bdb44f0` |
| Temurin 21 alpine aarch64 | 21.0.12.1+1 | `8242627927adc90ac2561d0812dd39890ebc21ef09b550bc2e8b93640b8af4f8` |
| Temurin 25 alpine x64 | 25.0.4.1+1 | `f18648ee5ce45261f50dc9493fdae7ddebaa2a7a857cafda3e2a448a79c03dee` |
| Temurin 25 alpine aarch64 | 25.0.4.1+1 | `8d19373d427017d86ac87cf6a47ba49746be864832f60b52b7e3b1531c6b2cb8` |

Temurin checksums are from the [Adoptium asset API](https://api.adoptium.net/v3/assets/latest/21/hotspot?os=alpine-linux&architecture=x64&image_type=jdk).

## Local build

```sh
make build
# or
podman build --format=oci --squash-all -t stripped-keycloak:26.7.2-alpine-jlink -f Containerfile .
```

Java 25:

```sh
make build JAVA_MAJOR=25
```

## Publish to GHCR

No registry secrets. The workflow logs in with `GITHUB_TOKEN` and pushes to `ghcr.io/<owner>/<repo>`.

`KEYCLOAK_VERSION` is pinned at `26.7.2`. That is the first public release that fixes [CVE-2026-18963](https://github.com/keycloak/keycloak/issues/51833) (unauthenticated account takeover via reset-credentials). The publish job refuses anything older. Alpine still comes from `docker.io/library/alpine`.

Push a version tag:

```sh
git tag v26.7.2
git push origin v26.7.2
```

That builds `linux/amd64` and `linux/arm64` and pushes:

- `ghcr.io/<owner>/stripped-keycloak:26.7.2`
- `ghcr.io/<owner>/stripped-keycloak:26.7.2-alpine-jlink`
- `ghcr.io/<owner>/stripped-keycloak:26.7.2-jdk21`
- `ghcr.io/<owner>/stripped-keycloak:latest`

`workflow_dispatch` can build JDK 25 or run a dry build without push.

The repo is private, so the GHCR package starts private. For a Nexus docker-proxy with no GitHub token, set the package visibility to public after the first push (Package settings → Change visibility).

## Pull through Nexus

Point CCE at a Nexus docker-proxy for `ghcr.io`, or copy once into a hosted repo / SWR:

```sh
skopeo copy \
  docker://ghcr.io/<owner>/stripped-keycloak:26.7.2-alpine-jlink \
  docker://nexus.example.com:18443/<repo>/stripped-keycloak:26.7.2-alpine-jlink
```

On CCE containerd do not digest-only pin through a proxy that returns `Content-Length: 0`. Use the immutable tag `26.7.2-alpine-jlink`.

## Helm override (CloudPirates wrap)

```yaml
keycloak:
  image:
    registry: nexus.example.com:18443
    repository: <repo>/stripped-keycloak
    tag: 26.7.2-alpine-jlink
    imagePullPolicy: IfNotPresent
  containerSecurityContext:
    runAsUser: 1000
    runAsGroup: 0
  keycloak:
    httpsEnabled: true
    httpEnabled: false
    extraArgs: ["--optimized"]
```

## Runtime

```sh
# dev
docker run --rm -p 8080:8080 -p 9000:9000 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=change_me \
  stripped-keycloak:26.7.2-alpine-jlink start-dev

# prod (image already baked for postgres)
docker run --rm -p 8443:8443 -p 9000:9000 \
  -e KC_DB_URL=jdbc:postgresql://db:5432/keycloak \
  -e KC_DB_USERNAME=keycloak \
  -e KC_DB_PASSWORD=change_me \
  -e KC_HOSTNAME=https://auth.example.com \
  -e KC_HTTP_MANAGEMENT_SCHEME=http \
  -e KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/certs/tls.crt \
  -e KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/certs/tls.key \
  -v keycloak-tls:/opt/keycloak/certs:ro \
  stripped-keycloak:26.7.2-alpine-jlink
```

Ports: `8080` HTTP, `8443` HTTPS, `9000` management, `7800`/`57800` JGroups (unused while `KC_CACHE=local`). Persist `/opt/keycloak/data`. Providers go in `/opt/keycloak/providers` before a rebuild.

## Bumping Keycloak

1. Change `KEYCLOAK_VERSION` and `KEYCLOAK_SHA256` in `Containerfile` and `.github/workflows/publish.yml`.
2. Tag `v<new-version>` and push.
