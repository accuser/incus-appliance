# Contributing to Incus Appliance Registry

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Ways to Contribute

- **Add new appliances** — Create definitions for useful applications
- **Improve existing appliances** — Optimize, update, or enhance current appliances
- **Fix bugs** — Report or fix issues in build scripts or templates
- **Improve documentation** — Clarify guides, add examples
- **Share feedback** — Suggest improvements or new features

## Development Workflow

This project uses **GitHub Flow** for all changes. See [CLAUDE.md](CLAUDE.md#development-workflow-github-flow) for complete workflow documentation.

### Quick Summary

1. Create a feature branch from `main`
2. Make your changes and commit
3. Push and create a Pull Request
4. Ensure CI checks pass
5. Merge using "Squash and merge"

### Branch Naming

- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions or improvements

## Getting Started

### Prerequisites

- Git
- Incus (>= 6.0)
- incus-extra (includes distrobuilder and incus-simplestreams)
- Basic shell scripting knowledge
- Familiarity with YAML

### Development Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/incus-appliance
cd incus-appliance

# Verify you can build
make validate
./bin/build-appliance.sh nginx

# Test locally
make serve &
incus remote add test https://localhost:8443 --protocol simplestreams --accept-certificate
make test-nginx
```

## Contributing an Appliance

### 1. Choose an Application

Good candidates for appliances:

✅ **Good Choices**
- Single-purpose services (nginx, redis, postgres)
- Development tools (git server, CI runners)
- Network services (DNS, DHCP, VPN)
- Monitoring tools (Prometheus, Grafana)
- Databases and caches

❌ **Not Suitable**
- Desktop applications
- Multi-purpose systems
- Applications requiring GUI
- Highly stateful systems without clear data paths

### 2. Create the Appliance

```bash
# Create directory structure
mkdir -p appliances/myapp/{files,profiles}

# Create required files
touch appliances/myapp/appliance.yaml
touch appliances/myapp/image.yaml
touch appliances/myapp/README.md
```

### 3. Write Templates

See [docs/creating-appliances.md](docs/creating-appliances.md) for detailed guidance.

Minimal `appliance.yaml`:
```yaml
name: myapp
version: "1.0.0"
description: "Clear, concise description"
base:
  distribution: debian
  release: bookworm
```

Minimal `image.yaml`:
```yaml
image:
  distribution: debian
  release: bookworm
  description: "MyApp appliance"

source:
  downloader: debootstrap
  url: https://deb.debian.org/debian
  variant: minbase

packages:
  manager: apt
  update: true
  cleanup: true
  sets:
    - packages: [myapp]
      action: install

actions:
  - trigger: post-packages
    action: |-
      systemctl enable myapp
```

### 4. Test Your Appliance

```bash
# Validate
make validate

# Build
make build-myapp

# Test
make serve &
make test-myapp
```

### 5. Document

Write a comprehensive README.md:

```markdown
# MyApp Appliance

Brief description of what the appliance does.

## Quick Start

\`\`\`bash
incus launch appliance:myapp my-instance
\`\`\`

## Configuration

How to configure the appliance...

## Networking

Which ports are used...

## Persistent Data

Which directories should be persisted...

## Common Tasks

Typical operations...
```

### 6. Submit Pull Request

```bash
# Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/add-myapp-appliance

# Commit changes
git add appliances/myapp/
git commit -m "Add myapp appliance

Adds a production-ready myapp appliance based on Debian Bookworm.
Includes configuration and health checks."

# Push and create PR
git push origin feature/add-myapp-appliance
gh pr create --title "Add myapp appliance"
```

## Code Standards

### Shell Scripts

- Use `#!/usr/bin/env bash`
- Start with `set -euo pipefail`
- Include comments for complex logic
- Use meaningful variable names
- Pass shellcheck

Example:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Build a single appliance
APPLIANCE="${1:?Usage: $0 <appliance-name>}"

if [[ ! -d "appliances/${APPLIANCE}" ]]; then
  echo "Error: Appliance not found"
  exit 1
fi
```

### YAML Files

- Use 2-space indentation
- No trailing whitespace
- Quote strings when ambiguous
- Sort keys alphabetically where sensible
- Pass yamllint

Example:
```yaml
name: myapp
version: "1.0.0"  # Quoted to prevent interpretation as float

packages:
  manager: apt
  sets:
    - action: install
      packages:
        - package-a
        - package-b
        - package-c
```

### Documentation

- Use clear, concise language
- Include code examples
- Assume readers are familiar with Incus basics
- Link to related documentation
- Spell-check and grammar-check

## Appliance Guidelines

### Security

1. **No default passwords**
   ```yaml
   # ❌ Bad
   actions:
     - trigger: post-packages
       action: echo "root:password123" | chpasswd

   # ✅ Good - use cloud-init
   # Document in README how to set password via user-data
   ```

2. **Run as non-root**
   ```yaml
   actions:
     - trigger: post-packages
       action: |-
         useradd --system --no-create-home --shell /usr/sbin/nologin myapp
         systemctl enable myapp
   ```

3. **Minimal packages**
   ```yaml
   # Only install what's needed
   packages:
     sets:
       - packages: [myapp, ca-certificates]
         action: install
   ```

### Size Optimization

1. **Use Debian as base**
   - Use Debian Bookworm for reliable cloud-init support
   - Provides broad compatibility with glibc

2. **Clean package cache**
   ```yaml
   packages:
     cleanup: true  # Always enable
   ```

3. **Remove build dependencies**
   ```yaml
   packages:
     sets:
       - packages: [build-base, cmake]
         action: install
       # ... build software ...
       - packages: [build-base, cmake]
         action: remove
   ```

### Documentation

Every appliance must include:

1. **appliance.yaml** — Metadata
2. **image.yaml** — Build template
3. **README.md** with:
   - Quick start example
   - Configuration instructions
   - Networking details
   - Persistent data locations
   - Common tasks
   - Troubleshooting

### Testing

Before submitting, verify:

- [ ] Template validates: `make validate`
- [ ] Image builds successfully: `make build-myapp`
- [ ] Instance launches: `incus launch test:myapp test-instance`
- [ ] Service starts correctly
- [ ] Health check passes: `make test-myapp`
- [ ] Documentation is clear and accurate
- [ ] No security issues (shellcheck, yamllint)

## Pull Request Process

This project uses **GitHub Flow** with squash merging. All changes must go through pull requests.

### Before Submitting

1. Create feature branch from latest `main`
2. Test your changes thoroughly
3. Update documentation
4. Run validation: `make validate`
5. Check for trailing whitespace
6. Ensure CI checks pass

### PR Description

Include:

- **What**: What does this PR add/fix?
- **Why**: Why is this change needed?
- **Testing**: How was it tested?
- **Screenshots**: If applicable

Example:
```markdown
## Add Redis Appliance

Adds a Redis appliance based on Debian Bookworm.

### Features
- Redis 7.0
- Persistence enabled by default
- Health check included
- Cloud-init support

### Testing
- Built successfully on amd64
- Launches and responds to PING
- Passes health check
- Documentation verified
```

### Review Process

1. Automated checks run (validation, linting, build tests)
2. All CI checks must pass before review
3. Maintainer reviews code and tests
4. Feedback addressed in additional commits
5. Once approved, use "Squash and merge" to merge to main
6. Delete feature branch after merge

## Commit Messages

Use conventional commits format:

```
type(scope): brief description

Longer description if needed

Closes #123
```

Types:
- `feat`: New appliance or feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(nginx): add nginx appliance

Adds a production-ready nginx appliance based on Debian Bookworm.
Includes reverse proxy configuration and health checks.

feat(scripts): add multi-arch build support

fix(nginx): correct health check endpoint

docs(readme): improve quick start guide

chore: update dependencies
```

## Code Review Guidelines

### For Reviewers

- Be constructive and respectful
- Test the appliance yourself
- Check security implications
- Verify documentation completeness
- Suggest improvements, don't demand perfection

### For Contributors

- Respond to feedback promptly
- Don't take criticism personally
- Ask questions if unclear
- Update based on feedback
- Thank reviewers for their time

## Building Community

### Be Welcoming

- Assume good intentions
- Be patient with newcomers
- Offer help and guidance
- Celebrate contributions

### Code of Conduct

We follow the [Contributor Covenant](https://www.contributor-covenant.org/):

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

## Getting Help

### Questions

- Check [existing documentation](docs/)
- Search [closed issues](https://github.com/yourusername/incus-appliance/issues?q=is%3Aissue+is%3Aclosed)
- Open a new issue with the `question` label

### Bugs

Report bugs by opening an issue:

1. Clear, descriptive title
2. Steps to reproduce
3. Expected vs actual behavior
4. System information (Incus version, OS, etc.)
5. Relevant logs

### Feature Requests

Suggest features by opening an issue:

1. Clear description of the feature
2. Use case / motivation
3. Example implementation (optional)

## Development Tips

### Fast Iteration

```bash
# Build and test in one command
make build-myapp && make test-myapp

# Watch for changes (requires entr)
ls appliances/myapp/* | entr -s 'make build-myapp'
```

### Debugging Builds

```bash
# Verbose distrobuilder output
sudo distrobuilder build-incus \
  appliances/myapp/image.yaml \
  --debug

# Inspect rootfs
mkdir /tmp/rootfs
sudo mount -t squashfs \
  .build/myapp/amd64/rootfs.squashfs \
  /tmp/rootfs
ls -la /tmp/rootfs
sudo umount /tmp/rootfs
```

### Testing in Container

```bash
# Launch and interact
incus launch test:myapp debug-instance
incus exec debug-instance -- bash

# Copy files in/out
incus file push test.conf debug-instance/etc/
incus file pull debug-instance/var/log/app.log ./

# Don't forget to clean up
incus delete -f debug-instance
```

## Recognition

Contributors are recognized in:

- README.md contributors section
- Release notes for significant contributions
- Special recognition for major features

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Don't hesitate to ask questions in:
- GitHub Issues
- GitHub Discussions
- Pull Request comments

Thank you for contributing! 🎉
