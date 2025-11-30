# Versioning Policy

This document describes the semantic versioning strategy for appliance images in the Incus Appliance Registry.

## Semantic Versioning

All appliances follow [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: Breaking changes (configuration incompatibilities, removed features)
- **MINOR**: New features, non-breaking changes
- **PATCH**: Bug fixes, security updates

## Version Sources

Versions are defined in each appliance's `appliance.yaml` file:

```yaml
name: nginx
version: "1.0.0"  # Semantic version
description: "Web server appliance"
```

The build system automatically extracts this version during the build process.

## Image Aliases

Each built image is published with multiple aliases for flexible version pinning:

| Alias Format | Example | Description |
|--------------|---------|-------------|
| `name` | `nginx` | Default, resolves to latest |
| `name:latest` | `nginx:latest` | Explicitly latest version |
| `name:X.Y.Z` | `nginx:1.0.0` | Exact version |
| `name:X.Y` | `nginx:1.0` | Latest patch in minor version |
| `name:X` | `nginx:1` | Latest minor in major version |

Architecture-specific variants are also available:

| Alias Format | Example |
|--------------|---------|
| `name/arch` | `nginx/amd64` |
| `name:version/arch` | `nginx:1.0.0/arm64` |

## Usage Examples

```bash
# Add the registry remote
incus remote add appliance https://example.github.io/incus-appliance --protocol simplestreams

# Launch latest version
incus launch appliance:nginx my-nginx

# Pin to exact version (recommended for production)
incus launch appliance:nginx:1.0.0 my-nginx

# Pin to major version (gets minor updates)
incus launch appliance:nginx:1 my-nginx

# Pin to minor version (gets patch updates)
incus launch appliance:nginx:1.0 my-nginx

# Specify architecture
incus launch appliance:nginx:1.0.0/arm64 my-nginx
```

## Version Pinning Recommendations

| Environment | Recommended Alias | Rationale |
|-------------|-------------------|-----------|
| Development | `name` or `name:latest` | Always use latest features |
| Staging | `name:X.Y` | Get patch fixes, predictable minor |
| Production | `name:X.Y.Z` | Full reproducibility |

## Updating Versions

### For Appliance Maintainers

1. Update the `version` field in `appliance.yaml`
2. Follow semantic versioning rules:
   - Increment PATCH for bug fixes
   - Increment MINOR for new features (reset PATCH to 0)
   - Increment MAJOR for breaking changes (reset MINOR and PATCH to 0)
3. Create a PR with the changes
4. Once merged, CI/CD automatically builds and publishes

### Version Bump Checklist

**PATCH bump** (e.g., 1.0.0 → 1.0.1):
- [ ] Security fixes
- [ ] Bug fixes
- [ ] Dependency updates (non-breaking)
- [ ] Documentation fixes

**MINOR bump** (e.g., 1.0.1 → 1.1.0):
- [ ] New features
- [ ] New configuration options
- [ ] Performance improvements
- [ ] Deprecations (with warnings)

**MAJOR bump** (e.g., 1.1.0 → 2.0.0):
- [ ] Breaking configuration changes
- [ ] Removed features
- [ ] Major base OS upgrade
- [ ] Changed default behaviors

## Release Strategy

### GitHub Releases

Each CI/CD run creates two releases:

1. **`latest`** - Always points to the most recent build
2. **`vYYYYMMDD`** - Date-stamped release for historical reference

### Changelog

Changelogs are automatically generated from git commits between releases. Use conventional commit messages for better changelogs:

```
feat: add nginx caching support
fix: correct permissions on log directory
docs: update configuration examples
```

## Rollback Procedures

To rollback to a previous version:

```bash
# List available versions
incus image list appliance: --format=csv | grep nginx

# Launch specific older version
incus launch appliance:nginx:1.0.0 my-nginx-rollback

# Or copy the old image locally first
incus image copy appliance:nginx:1.0.0 local: --alias nginx-stable
incus launch nginx-stable my-nginx
```

## Multi-Architecture Support

All versions are built for multiple architectures (typically amd64 and arm64). The registry automatically serves the correct architecture based on your host system, or you can explicitly specify:

```bash
# Auto-detect (recommended)
incus launch appliance:nginx:1.0.0 my-nginx

# Explicit architecture
incus launch appliance:nginx:1.0.0/arm64 my-nginx
```

## FAQ

**Q: What happens when I use `nginx` without a version?**
A: You get the latest version. The `nginx` alias always points to the most recent build.

**Q: Can I see what version I'm running?**
A: Check the image alias or fingerprint:
```bash
incus config show my-nginx | grep -A5 "image:"
```

**Q: How do I know when a new version is available?**
A: Watch the GitHub releases or check the registry:
```bash
incus image list appliance: nginx
```

**Q: Are old versions kept forever?**
A: Date-stamped releases are retained. The exact retention policy depends on repository settings.
