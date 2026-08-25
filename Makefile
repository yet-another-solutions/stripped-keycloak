IMAGE ?= stripped-keycloak
KEYCLOAK_VERSION ?= 26.7.2
JAVA_MAJOR ?= 21
PLATFORM ?= linux/amd64

.PHONY: build build-multi run-dev run-prod

build:
	docker buildx build \
	  --load \
	  --platform $(PLATFORM) \
	  --file Containerfile \
	  --build-arg JAVA_MAJOR=$(JAVA_MAJOR) \
	  --build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
	  --build-arg KC_DB=postgres \
	  --build-arg KC_HEALTH_ENABLED=true \
	  --build-arg KC_METRICS_ENABLED=true \
	  --build-arg KC_CACHE=local \
	  --tag $(IMAGE):$(KEYCLOAK_VERSION)-alpine-jlink \
	  --tag $(IMAGE):$(KEYCLOAK_VERSION)-jdk$(JAVA_MAJOR) \
	  .

build-multi:
	docker buildx build \
	  --platform linux/amd64,linux/arm64 \
	  --file Containerfile \
	  --build-arg JAVA_MAJOR=$(JAVA_MAJOR) \
	  --build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
	  --build-arg KC_DB=postgres \
	  --build-arg KC_HEALTH_ENABLED=true \
	  --build-arg KC_METRICS_ENABLED=true \
	  --build-arg KC_CACHE=local \
	  --tag $(IMAGE):$(KEYCLOAK_VERSION)-alpine-jlink \
	  .

run-dev:
	docker run --rm -it --name keycloak \
	  -p 8080:8080 -p 9000:9000 \
	  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
	  -e KC_BOOTSTRAP_ADMIN_PASSWORD=change_me \
	  $(IMAGE):$(KEYCLOAK_VERSION)-alpine-jlink \
	  start-dev

run-prod:
	docker run --rm -it --name keycloak \
	  -p 8443:8443 -p 9000:9000 \
	  -e KC_DB_URL=jdbc:postgresql://db:5432/keycloak \
	  -e KC_DB_USERNAME=keycloak \
	  -e KC_DB_PASSWORD=change_me \
	  -e KC_HOSTNAME=https://auth.example.com \
	  -e KC_HTTP_MANAGEMENT_SCHEME=http \
	  -e KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/certs/tls.crt \
	  -e KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/certs/tls.key \
	  $(IMAGE):$(KEYCLOAK_VERSION)-alpine-jlink \
	  start --optimized
