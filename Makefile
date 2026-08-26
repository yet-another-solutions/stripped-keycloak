IMAGE ?= stripped-keycloak
OPERATOR_IMAGE ?= stripped-keycloak-operator
KEYCLOAK_VERSION ?= 26.7.2
JAVA_MAJOR ?= 21
OPERATOR_JAVA_MAJOR ?= 25
PLATFORM ?= linux/amd64
RELATED_IMAGE_KEYCLOAK ?= ghcr.io/yet-another-solutions/stripped-keycloak:$(KEYCLOAK_VERSION)

.PHONY: all build build-keycloak build-operator build-multi lint run-dev run-prod

all: build-keycloak build-operator

build: build-keycloak

lint:
	hadolint --config .hadolint.yaml keycloak/Containerfile operator/Containerfile

build-keycloak:
	docker buildx build \
	  --load \
	  --platform $(PLATFORM) \
	  --file keycloak/Containerfile \
	  --build-arg JAVA_MAJOR=$(JAVA_MAJOR) \
	  --build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
	  --build-arg KC_DB=postgres \
	  --build-arg KC_HEALTH_ENABLED=true \
	  --build-arg KC_METRICS_ENABLED=true \
	  --build-arg KC_CACHE=local \
	  --tag $(IMAGE):$(KEYCLOAK_VERSION)-alpine-jlink \
	  --tag $(IMAGE):$(KEYCLOAK_VERSION)-jdk$(JAVA_MAJOR) \
	  keycloak

build-operator:
	docker buildx build \
	  --load \
	  --platform $(PLATFORM) \
	  --file operator/Containerfile \
	  --build-arg JAVA_MAJOR=$(OPERATOR_JAVA_MAJOR) \
	  --build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
	  --build-arg RELATED_IMAGE_KEYCLOAK=$(RELATED_IMAGE_KEYCLOAK) \
	  --tag $(OPERATOR_IMAGE):$(KEYCLOAK_VERSION)-alpine-jlink \
	  --tag $(OPERATOR_IMAGE):$(KEYCLOAK_VERSION)-jdk$(OPERATOR_JAVA_MAJOR) \
	  operator

build-multi:
	docker buildx build \
	  --platform linux/amd64,linux/arm64 \
	  --file keycloak/Containerfile \
	  --build-arg JAVA_MAJOR=$(JAVA_MAJOR) \
	  --build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
	  --build-arg KC_DB=postgres \
	  --build-arg KC_HEALTH_ENABLED=true \
	  --build-arg KC_METRICS_ENABLED=true \
	  --build-arg KC_CACHE=local \
	  --tag $(IMAGE):$(KEYCLOAK_VERSION)-alpine-jlink \
	  keycloak
	docker buildx build \
	  --platform linux/amd64,linux/arm64 \
	  --file operator/Containerfile \
	  --build-arg JAVA_MAJOR=$(OPERATOR_JAVA_MAJOR) \
	  --build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
	  --build-arg RELATED_IMAGE_KEYCLOAK=$(RELATED_IMAGE_KEYCLOAK) \
	  --tag $(OPERATOR_IMAGE):$(KEYCLOAK_VERSION)-alpine-jlink \
	  operator

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
