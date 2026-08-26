# stripped-keycloak

Two images, one repository. Both are Alpine 3.24.1 plus a Temurin musl `jlink` JRE. Official Quay/UBI runtimes are not used. Java is not an apk or RPM package. `apk` is deleted from the final layer.

| Image | Path | GHCR |
| --- | --- | --- |
| Keycloak server | `keycloak/Containerfile` | `ghcr.io/<owner>/stripped-keycloak` |
| Keycloak operator | `operator/Containerfile` | `ghcr.io/<owner>/stripped-keycloak-operator` |

GitHub Actions builds on public runners (Keycloak tarball, Adoptium JDK, and the official operator image are reachable) and publishes to GHCR. Containerfiles still pull Alpine from docker.io. Internal Jenkins and CCE only pull the baked images through Nexus.

## stripped-keycloak

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

`wget` and `binutils` (`objcopy` for `jlink --strip-debug`) are install-only in builder stages and `apk del`'d there. They do not land in the final image. Temurin 25+ has no `jmods` directory ([JEP 493](https://openjdk.org/jeps/493)); that path lists modules with `java --list-modules` and jlinks the linkable runtime.

## stripped-keycloak-operator

Same Alpine + Temurin jlink principle. The official operator image is `ubi9-micro` + `java-25-openjdk-headless` wrapping a Quarkus JVM app. There is no operator tarball on GitHub releases, so the build copies `/opt/keycloak` (the `quarkus-app` tree) from the pinned official image and throws the UBI runtime away.

| Layer | What it is | What it is not |
| --- | --- | --- |
| Operator | `quarkus-app` from `quay.io/keycloak/keycloak-operator:26.7.2` (index digest pinned) | UBI micro, RH OpenJDK |
| Java | Temurin musl JDK, `jlink`'d (25 default, to match the official operator) | Alpine or RHEL OpenJDK |
| OS | Alpine musl, busybox, certs, tz, zlib, libstdc++ | UBI, bash, apk |
| User | UID 1000, GID 0, `g+rwX` on `/opt/keycloak` | root |
| Entry | `java -Djava.util.logging.manager=org.jboss.logmanager.LogManager -jar quarkus-run.jar` | any custom command |
| Port | `8080` (Quarkus HTTP + `/q/health/*`) | Keycloak 8443/9000 |

Baked defaults (overridable at deploy time):

- `RELATED_IMAGE_KEYCLOAK=ghcr.io/yet-another-solutions/stripped-keycloak:26.7.2` so the operator does not pull UBI Keycloak
- `KC_OPERATOR_KEYCLOAK_START_OPTIMIZED=true` because the paired server image is already `kc.sh build`'d

Do not override the container command. The official operator Deployment does not set `command`/`args`; probes hit `8080` at `/q/health/live`, `/q/health/ready`, `/q/health/started`.


## Pins

| Artifact | Version | SHA256 / digest |
| --- | --- | --- |
| [keycloak-26.7.2.tar.gz](https://github.com/keycloak/keycloak/releases/download/26.7.2/keycloak-26.7.2.tar.gz) | 26.7.2 | `4f3ce3b797a9d98998b7f1a6bd5d2b9832100faea66c48988713a9b23eda5c44` |
| [keycloak-operator:26.7.2](https://quay.io/repository/keycloak/keycloak-operator?tab=tags) | 26.7.2 | `sha256:d1a54bc1032891851085625882343bbc8918c87993a0a32ba044640735db91be` (OCI index) |
| Temurin 21 alpine x64 | 21.0.12.1+1 | `bd8824214e42b33333c7f55a039ea078ad6ea6be20d7c5b011c801fb2bdb44f0` |
| Temurin 21 alpine aarch64 | 21.0.12.1+1 | `8242627927adc90ac2561d0812dd39890ebc21ef09b550bc2e8b93640b8af4f8` |
| Temurin 25 alpine x64 | 25.0.4.1+1 | `f18648ee5ce45261f50dc9493fdae7ddebaa2a7a857cafda3e2a448a79c03dee` |
| Temurin 25 alpine aarch64 | 25.0.4.1+1 | `8d19373d427017d86ac87cf6a47ba49746be864832f60b52b7e3b1531c6b2cb8` |

Temurin checksums are from the [Adoptium asset API](https://api.adoptium.net/v3/assets/latest/21/hotspot?os=alpine-linux&architecture=x64&image_type=jdk).

## Local build

```sh
make all
# or separately
make build-keycloak
make build-operator
```

```sh
podman build --format=oci --squash-all -t stripped-keycloak:26.7.2-alpine-jlink -f keycloak/Containerfile keycloak
podman build --format=oci --squash-all -t stripped-keycloak-operator:26.7.2-alpine-jlink -f operator/Containerfile operator
```

Java 25 for the server:

```sh
make build-keycloak JAVA_MAJOR=25
```

## Publish to GHCR

No registry secrets. The workflow logs in with `GITHUB_TOKEN` and pushes both packages.

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
- `ghcr.io/<owner>/stripped-keycloak-operator:26.7.2`
- `ghcr.io/<owner>/stripped-keycloak-operator:26.7.2-alpine-jlink`
- `ghcr.io/<owner>/stripped-keycloak-operator:26.7.2-jdk25`
- `ghcr.io/<owner>/stripped-keycloak-operator:latest`

`workflow_dispatch` can build the server with JDK 25 or run a dry build without push. Operator Java stays 25.

Pre-release tags (`v26.7.2-pre.1`, `v26.7.2-rc.1`) publish under that tag name, mark the GitHub Release as a pre-release, and do not move `26.7.2` or `latest`.

The repo is private, so GHCR packages start private. For a Nexus docker-proxy with no GitHub token, set each package visibility to public after the first push (Package settings → Change visibility).

## Pull through Nexus

Point CCE at a Nexus docker-proxy for `ghcr.io`, or copy once into a hosted repo / SWR:

```sh
skopeo copy \
  docker://ghcr.io/<owner>/stripped-keycloak:26.7.2-alpine-jlink \
  docker://nexus.example.com:18443/<repo>/stripped-keycloak:26.7.2-alpine-jlink

skopeo copy \
  docker://ghcr.io/<owner>/stripped-keycloak-operator:26.7.2-alpine-jlink \
  docker://nexus.example.com:18443/<repo>/stripped-keycloak-operator:26.7.2-alpine-jlink
```

On CCE containerd do not digest-only pin through a proxy that returns `Content-Length: 0`. Use the immutable tag `26.7.2-alpine-jlink`.


## Operator install

No OLM. No Helm: the Keycloak project does not ship an operator chart ([issue 37636](https://github.com/keycloak/keycloak/issues/37636)). Without OLM the supported path is the plain YAML in [keycloak-k8s-resources](https://github.com/keycloak/keycloak-k8s-resources).

That YAML is not copied into this repo. `scripts/rewrite-operator-manifests.sh` fetches the tag that matches `KEYCLOAK_VERSION` and `sed`-replaces the two Quay image refs:

- `quay.io/keycloak/keycloak-operator:26.7.2` → `ghcr.io/<owner>/stripped-keycloak-operator:26.7.2`
- `quay.io/keycloak/keycloak:26.7.2` (`RELATED_IMAGE_KEYCLOAK`) → `ghcr.io/<owner>/stripped-keycloak:26.7.2`

A `v*` tag runs that script after the images are published and attaches the files to the GitHub Release. CRDs are included unchanged.

```sh
make operator-manifests
kubectl create namespace keycloak
kubectl apply -k dist/operator-manifests
```

From a release asset:

```sh
kubectl create namespace keycloak
kubectl apply -f stripped-keycloak-operator-install-26.7.2.yml
```

That installs CRDs and the operator Deployment. It does not create a `Keycloak` custom resource.

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

1. Change `KEYCLOAK_VERSION` and `KEYCLOAK_SHA256` in `keycloak/Containerfile`.
2. Change `OPERATOR_DIST_IMAGE` (tag + index digest) in `operator/Containerfile`.
3. Change `KEYCLOAK_VERSION` in `.github/workflows/publish.yml` and the default `RELATED_IMAGE_KEYCLOAK`.
4. Tag `v<new-version>` and push.
