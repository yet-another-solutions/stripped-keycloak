# Third-party notices

This repository's Containerfiles and scripts are Apache-2.0 (see `LICENSE`).
Images built from them also contain the following third-party components.
Keycloak itself ships no `NOTICE` file; the official 26.7.2 tarball's only
license artifact is `LICENSE.txt`.

## Keycloak server (operand)

| Component | License | Source |
| --- | --- | --- |
| Keycloak 26.7.2 distribution | Apache-2.0 | https://github.com/keycloak/keycloak |
| MySQL Connector/J 9.6.0 (in the dist) | GPLv2 + Universal FOSS Exception v1.0 | https://github.com/mysql/mysql-connector-j |
| MariaDB Connector/J 3.5.9 (in the dist) | LGPL-2.1-or-later | https://mariadb.com/kb/en/about-mariadb-connector-j/ |
| H2 2.4.240 (in the dist) | MPL-2.0 or EPL-1.0 | https://h2database.com/html/license.html |

The official tarball is fetched at build time (`KEYCLOAK_SHA256` in
`keycloak/Containerfile`). `/opt/keycloak/LICENSE.txt` is kept.

## Keycloak Operator

| Component | License | Source |
| --- | --- | --- |
| Operator `quarkus-app` from `quay.io/keycloak/keycloak-operator:26.7.2` | Apache-2.0 | https://github.com/keycloak/keycloak |
| Rewritten install YAML from `keycloak/keycloak-k8s-resources` | Apache-2.0 | https://github.com/keycloak/keycloak-k8s-resources |

The official operator image does not ship a license file under
`/opt/keycloak`. This rebuild copies Apache-2.0 to
`/opt/keycloak/LICENSE.txt`. UBI is not redistributed.

## Eclipse Temurin / OpenJDK

| Component | License | Source |
| --- | --- | --- |
| Eclipse Temurin musl JDK, then `jlink` | GPLv2 with Classpath Exception | https://adoptium.net/ |

Classpath Exception: Keycloak is an independent module and is not
copylefted. The JRE itself still needs GPL notices and corresponding
source. Image path: `/licenses/temurin/` and `/opt/java/legal/`.

## Alpine userland

| Component | License | Source |
| --- | --- | --- |
| BusyBox, apk-tools, alpine-baselayout, scanelf, ssl_client | GPL-2.0-only | https://busybox.net/ https://gitlab.alpinelinux.org/alpine/aports |
| musl | MIT | https://musl.libc.org/ |
| Other apk packages | see `/licenses/alpine-packages.txt` | Alpine 3.24.1 |

BusyBox GPL does not copyleft Keycloak (mere aggregation). Corresponding
source is offered in `/licenses/SOURCE-OFFER.txt`.

## Fonts (server image)

DejaVu, FreeType, and fontconfig as packaged by Alpine. Typical terms
include Bitstream Vera and FTL-style licenses.

## Trademarks

Keycloak is a trademark of The Linux Foundation.
Eclipse Temurin is a trademark of the Eclipse Foundation AISBL.
Java is a trademark of Oracle.
This project is not affiliated with or sponsored by those owners.
