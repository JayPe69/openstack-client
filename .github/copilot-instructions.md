# OpenStack CLI Docker Image

**ALWAYS follow these instructions first and fallback to additional search and context gathering only if the information in the instructions is incomplete or found to be in error.**

This repository builds a lightweight `python:3.12-alpine` Docker image (multi-stage) containing the OpenStack CLI clients: openstackclient 10.4.0, octaviaclient 3.15.0, cinderclient 9.10.0 and neutronclient 14.0.0. The image is automatically built and published to Docker Hub at [jnovent/openstack-cli](https://hub.docker.com/r/jnovent/openstack-cli).

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
- **Alternative**: Pull and test existing image: `docker pull jnovent/openstack-cli:latest`

### Testing and Validation
1. **Pull Image**: `docker pull jnovent/openstack-cli:latest`
2. **Version**: `docker run --rm jnovent/openstack-cli:latest --version`
   - Expected output: `openstack 10.4.0`
3. **Help**: `docker run --rm jnovent/openstack-cli:latest --help`
4. **Subcommand help**: `docker run --rm jnovent/openstack-cli:latest server list --help`
5. **With clouds.yaml** (requires a real cloud):
   ```bash
   docker run --rm -v $(pwd)/clouds.yaml:/root/.config/openstack/clouds.yaml:ro jnovent/openstack-cli:latest --os-cloud mycloud server list
   ```

## CI/CD Pipeline
- **Schedule**: Every Monday at 8:00 AM UTC, plus manual `workflow_dispatch`
- **Platforms**: linux/amd64, linux/arm64
- **Registry**: Docker Hub (jnovent/openstack-cli)
- **Tags**: `latest` and `YYYYMMDD`
- **Build**: `no-cache: true`
- **NEVER CANCEL**: Multi-platform builds (arm64 compiles wheels under emulation) can take 15+ minutes

### Required Secrets
- `DOCKER_USERNAME`: Docker Hub username
- `DOCKER_PASSWORD`: Docker Hub password/token

## Dockerfile Modifications
- Keep the multi-stage structure; build tooling must stay in the builder stage
- Client versions are controlled by the `VERSION`, `OCTAVIA_VERSION`, `CINDER_VERSION`, `NEUTRON_VERSION` build args
- Use `apk --no-cache` for package installations
- Do not add heatclient/glanceclient separately unless `openstack --help` shows a missing plugin

## Validation Checklist
- [ ] Dockerfile syntax is correct
- [ ] `.dockerignore` excludes unnecessary files
- [ ] GitHub Actions workflow validates
- [ ] `--version` prints `openstack 10.4.0`
- [ ] `server list --help` works
