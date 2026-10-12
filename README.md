# OpenStack CLI Docker Image

Lightweight Alpine-based Docker image (`python:3.12-alpine`) embedding the OpenStack command-line clients:

- `python-openstackclient` 10.4.0
- `python-octaviaclient` 3.15.0
- `python-cinderclient` 9.10.0
- `python-neutronclient` 14.0.0

The image is rebuilt every Monday at 8:00 AM UTC (a new GitHub tag is created only when a new python-openstackclient version is released; otherwise the existing tag is rebuilt to pick up security updates) and published to Docker Hub as [jnovent/openstack-client](https://hub.docker.com/r/jnovent/openstack-client). Docker Hub tags include `latest`, `v<openstackclient version>` (e.g. `v10.4.0`, identical to the GitHub tag), and each OpenStack release series currently marked `maintained` (format: `<year>.<series>`). The image runs as the non-root user `openstack`.

Maintained-series tags are generated from the official OpenStack release status metadata. The release series script uses Ruby's standard YAML library, available on the GitHub-hosted Ubuntu runner.

## Basic Usage

```bash
docker pull jnovent/openstack-client:latest

# Help and version
docker run --rm jnovent/openstack-client:latest --help
docker run --rm jnovent/openstack-client:latest --version
```

## Using a clouds.yaml

Mount your `clouds.yaml` read-only:

```bash
docker run --rm \
  -v $(pwd)/clouds.yaml:/home/openstack/.config/openstack/clouds.yaml:ro \
  jnovent/openstack-client:latest --os-cloud mycloud server list
```

Or mount your whole OpenStack configuration directory:

```bash
docker run --rm \
  -v ~/.config/openstack:/home/openstack/.config/openstack \
  jnovent/openstack-client:latest --os-cloud mycloud server list
```

### Examples

```bash
docker run --rm -v ~/.config/openstack:/home/openstack/.config/openstack jnovent/openstack-client:latest --os-cloud mycloud server list
docker run --rm -v ~/.config/openstack:/home/openstack/.config/openstack jnovent/openstack-client:latest --os-cloud mycloud image list
docker run --rm -v ~/.config/openstack:/home/openstack/.config/openstack jnovent/openstack-client:latest --os-cloud mycloud network list
docker run --rm -v ~/.config/openstack:/home/openstack/.config/openstack jnovent/openstack-client:latest --os-cloud mycloud volume list
docker run --rm -v ~/.config/openstack:/home/openstack/.config/openstack jnovent/openstack-client:latest --os-cloud mycloud loadbalancer list
```

## Advanced Usage

### Environment variables

```bash
# Select a cloud from clouds.yaml
docker run --rm -e OS_CLOUD=mycloud \
  -v ~/.config/openstack:/home/openstack/.config/openstack \
  jnovent/openstack-client:latest server list

# Or authenticate with explicit variables
docker run --rm \
  -e OS_AUTH_URL=https://keystone.example.com:5000/v3 \
  -e OS_USERNAME=myuser \
  -e OS_PASSWORD=mypassword \
  -e OS_PROJECT_NAME=myproject \
  -e OS_USER_DOMAIN_NAME=Default \
  -e OS_PROJECT_DOMAIN_NAME=Default \
  jnovent/openstack-client:latest server list
```

### Interactive mode

Use `-it` for an interactive OpenStack shell:

```bash
docker run -it --rm \
  -v ~/.config/openstack:/home/openstack/.config/openstack \
  -e OS_CLOUD=mycloud \
  jnovent/openstack-client:latest
```

## Build locally

```bash
docker build --build-arg VERSION=$(./scripts/get-latest-version.sh) -t openstack-cli .
docker run --rm openstack-cli --version
```

## Required GitHub secrets

- `DOCKER_USERNAME`: Docker Hub username
- `DOCKER_PASSWORD`: Docker Hub password/token
