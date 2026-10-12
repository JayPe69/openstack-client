ARG VERSION=10.4.0
ARG OCTAVIA_VERSION=3.15.0
ARG CINDER_VERSION=9.10.0
ARG NEUTRON_VERSION=14.0.0

FROM python:3.12-alpine AS builder

ARG VERSION
ARG OCTAVIA_VERSION
ARG CINDER_VERSION
ARG NEUTRON_VERSION

RUN apk add --no-cache gcc python3-dev musl-dev linux-headers libffi-dev openssl-dev cargo rust

RUN pip install --no-cache-dir wheel \
    python-openstackclient==${VERSION} \
    python-octaviaclient==${OCTAVIA_VERSION} \
    python-cinderclient==${CINDER_VERSION} \
    python-neutronclient==${NEUTRON_VERSION} \
    && pip freeze > requirements.txt \
    && pip wheel -r requirements.txt -w /wheels

FROM python:3.12-alpine

RUN apk update --no-cache && apk upgrade --no-cache && apk add --no-cache ca-certificates curl

COPY --from=builder /wheels /wheels

RUN pip install --no-cache --no-index --find-links=/wheels python-openstackclient python-octaviaclient python-cinderclient python-neutronclient \
    && rm -rf /wheels /root/.cache

RUN addgroup -S openstack && adduser -S -G openstack -h /home/openstack openstack \
    && mkdir -p /home/openstack/.config/openstack \
    && chown -R openstack:openstack /home/openstack

USER openstack
WORKDIR /home/openstack

ENTRYPOINT ["openstack"]
CMD ["--help"]
