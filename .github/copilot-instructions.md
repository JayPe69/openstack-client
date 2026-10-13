# OpenStack CLI Docker Image

**ALWAYS follow these instructions first and fallback to additional search and context gathering only if the information in the instructions is incomplete or found to be in error.**

This repository builds a lightweight `python:3.12-alpine` Docker image (multi-stage) containing the OpenStack CLI clients: openstackclient 10.4.0, octaviaclient 3.15.0, cinderclient 9.10.0 and neutronclient 14.0.0. The image is automatically built and published to Docker Hub at [jnovent/openstack-client](https://hub.docker.com/r/jnovent/openstack-client).

## Working Effectively

### Repository Structure
- **Dockerfile**: Multi-stage build (builder compiles wheels, final stage installs them), `ENTRYPOINT ["openstack"]`, `CMD ["--help"]`
- **README.md**: Usage documentation
- **.dockerignore**: Standard Docker ignore patterns
- **.github/workflows/build-and-push.yml**: CI/CD pipeline for automated builds

### Build Process
- **Local Docker Build**: `docker build -t openstack-cli .`
  - May fail in sandboxed environments due to network/firewall limitations (Alpine/PyPI access)
  - **NEVER CANCEL**: Always wait for builds to complete or fail naturally; compiling wheels can take several minutes
- **Latest version**: `./scripts/get-latest-version.sh`
- **Alternative**: Pull and test existing image: `docker pull jnovent/openstack-client:latest`

### Testing and Validation
1. **Pull Image**: `docker pull jnovent/openstack-client:latest`
2. **Version**: `docker run --rm jnovent/openstack-client:latest --version`
   - Expected output: `openstack 10.4.0`
3. **Help**: `docker run --rm jnovent/openstack-client:latest --help`
4. **Subcommand help**: `docker run --rm jnovent/openstack-client:latest server list --help`
5. **With clouds.yaml** (requires a real cloud):
   ```bash
   docker run --rm -v $(pwd)/clouds.yaml:/home/openstack/.config/openstack/clouds.yaml:ro jnovent/openstack-client:latest --os-cloud mycloud server list
   ```

## CI/CD Pipeline
- **Schedule**: Every Monday at 8:00 AM UTC, plus manual `workflow_dispatch`
- **Platforms**: linux/amd64, linux/arm64
- **Registry**: Docker Hub (jnovent/openstack-client)
- **Docker Hub tags**: `<codename>-<version>` for each maintained series and the latest PyPI image (for example `hibiscus-10.3.0` and `hibiscus-10.4.0`), plus `latest`; maintained series each build in a parallel matrix job. GitHub release tags are separate and created only when a new openstackclient version appears; scheduled builds otherwise refresh images for security updates
- **Version detection**: `scripts/get-latest-version.sh` queries PyPI and its output is passed as the `VERSION` build arg
- **OpenStack series**: `scripts/get-maintained-openstack-builds.sh` maps maintained codenames to `python-openstackclient` versions on their official stable branches
- **Other clients**: `scripts/get-latest-{octavia,cinder,neutron}-version.sh` feed `OCTAVIA_VERSION`, `CINDER_VERSION`, `NEUTRON_VERSION`; all 4 versions are listed in the GitHub release notes
- **Runtime user**: non-root `openstack` (home `/home/openstack`)
- **Build**: `no-cache: true`
- **NEVER CANCEL**: Multi-platform builds (arm64 compiles wheels under emulation) can take 15+ minutes

### Required Secrets
- `DOCKER_USERNAME`: Docker Hub username
- `DOCKER_PASSWORD`: Docker Hub password/token

## Dockerfile Modifications
- Keep the multi-stage structure; build tooling must stay in the builder stage
- Client versions are controlled by the `VERSION`, `OCTAVIA_VERSION`, `CINDER_VERSION`, `NEUTRON_VERSION` build args
- Keep the non-root `USER openstack`
- Use `apk --no-cache` for package installations
- Do not add heatclient/glanceclient separately unless `openstack --help` shows a missing plugin

## Validation Checklist
- [ ] Dockerfile syntax is correct
- [ ] `.dockerignore` excludes unnecessary files
- [ ] GitHub Actions workflow validates
- [ ] `--version` prints `openstack 10.4.0`
- [ ] `server list --help` works
