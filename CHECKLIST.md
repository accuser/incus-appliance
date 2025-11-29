# Implementation Checklist

Use this checklist to verify your Incus Appliance Registry is properly set up.

## ✅ Installation & Prerequisites

- [ ] Incus installed and initialized (`incus --version`)
- [ ] distrobuilder installed (`distrobuilder --version`)
- [ ] Python 3 available (`python3 --version`)
- [ ] OpenSSL available (`openssl version`)
- [ ] Sufficient disk space (5GB+ for builds)
- [ ] Sudo access available

## ✅ Project Setup

- [ ] Repository cloned or files copied
- [ ] All scripts are executable (`chmod +x bin/*.sh scripts/*.sh`)
- [ ] Directory structure is correct
- [ ] .gitignore is in place

## ✅ Build System

- [ ] Can validate templates (`./bin/validate.sh`)
- [ ] Can build nginx appliance (`sudo ./bin/build-appliance.sh nginx`)
- [ ] Registry directory is created
- [ ] Build artifacts in `.build/nginx/amd64/`
- [ ] Cache directory `.cache/distrobuilder/` exists

## ✅ Local Testing

- [ ] Test server starts (`./scripts/serve-local.sh`)
- [ ] Certificates generated in `.certs/`
- [ ] Can access https://localhost:8443 (browser or curl)
- [ ] Can add test remote to Incus
- [ ] Can list images from test remote
- [ ] Can launch instance from test remote
- [ ] Instance starts and runs
- [ ] Health check passes

## ✅ Nginx Appliance

- [ ] Image builds successfully
- [ ] Instance launches
- [ ] Nginx service is running
- [ ] Can access welcome page (curl localhost)
- [ ] Health endpoint responds (curl localhost/health)
- [ ] Can push configuration files
- [ ] Can reload nginx (nginx -s reload)
- [ ] Logs are accessible

## ✅ Documentation

- [ ] README.md is complete
- [ ] QUICKSTART.md is present
- [ ] GETTING_STARTED.md is clear
- [ ] docs/creating-appliances.md exists
- [ ] docs/architecture.md explains system
- [ ] docs/deployment.md has deployment options
- [ ] CONTRIBUTING.md has guidelines
- [ ] All scripts have inline comments

## ✅ Scripts

- [ ] `bin/build-appliance.sh` works
- [ ] `bin/build-all.sh` works
- [ ] `bin/validate.sh` passes
- [ ] `bin/test-appliance.sh` passes
- [ ] `bin/test-all.sh` works
- [ ] `scripts/serve-local.sh` starts server
- [ ] `scripts/publish.sh` has deploy logic

## ✅ Makefile (if using Make)

- [ ] `make help` shows targets
- [ ] `make validate` works
- [ ] `make build-nginx` works
- [ ] `make serve` starts server
- [ ] `make test-nginx` passes
- [ ] `make list` shows appliances
- [ ] `make clean` removes artifacts

## ✅ Templates

- [ ] appliances/nginx/appliance.yaml is valid YAML
- [ ] appliances/nginx/image.yaml is valid YAML
- [ ] appliances/nginx/files/ contains config files
- [ ] appliances/nginx/README.md is complete
- [ ] appliances/_base/ has base templates
- [ ] All YAML passes yamllint (if available)

## ✅ Registry

- [ ] registry/streams/v1/index.json exists
- [ ] registry/streams/v1/images.json exists
- [ ] registry/images/<fingerprint>/ has files
- [ ] incus.tar.xz is present
- [ ] rootfs.squashfs is present
- [ ] Can list images with incus-simplestreams

## ✅ Profiles

- [ ] profiles/appliance-base.yaml exists
- [ ] profiles/README.md explains usage
- [ ] Can create profile in Incus
- [ ] Can launch with profile

## ✅ CI/CD (Optional)

- [ ] .github/workflows/validate.yml exists
- [ ] GitHub Actions would run (if using GitHub)
- [ ] All paths in workflow are correct

## ✅ Production Readiness

- [ ] SSL certificates configured (not self-signed)
- [ ] Web server configured (nginx/caddy/apache)
- [ ] Registry deployed to web server
- [ ] DNS configured
- [ ] Can add production remote
- [ ] Can launch from production remote
- [ ] Monitoring configured
- [ ] Backup strategy in place

## ✅ Security

- [ ] No default passwords in images
- [ ] Services run as non-root users
- [ ] Minimal package sets
- [ ] SSL/TLS enabled
- [ ] File permissions are correct
- [ ] No secrets in repository

## ✅ Testing

- [ ] All appliances build without errors
- [ ] All appliances launch successfully
- [ ] Health checks pass
- [ ] Services start automatically
- [ ] Can access services
- [ ] Configuration can be modified
- [ ] Snapshots work
- [ ] Restores work

## ✅ Documentation Accuracy

- [ ] All commands in docs are correct
- [ ] All file paths are accurate
- [ ] Examples work as written
- [ ] Links are valid
- [ ] Code blocks have proper syntax

## ✅ User Experience

- [ ] Clear error messages
- [ ] Helpful usage instructions
- [ ] Examples are practical
- [ ] Common issues documented
- [ ] FAQ addresses real questions

## Next Steps After Checklist

Once everything is checked:

1. **Test end-to-end workflow**
   ```bash
   # Fresh build
   sudo ./bin/build-appliance.sh nginx
   
   # Test locally
   ./scripts/serve-local.sh &
   ./bin/test-appliance.sh nginx
   
   # Deploy
   ./scripts/publish.sh
   ```

2. **Create your first custom appliance**
   - Follow docs/creating-appliances.md
   - Use nginx as reference
   - Test thoroughly

3. **Deploy to production**
   - Follow docs/deployment.md
   - Choose hosting option
   - Configure SSL properly
   - Set up monitoring

4. **Share and contribute**
   - Star the repository
   - Share with community
   - Contribute new appliances
   - Report issues and feedback

## Troubleshooting

If any checks fail, refer to:

- **Build issues** → [GETTING_STARTED.md](GETTING_STARTED.md) Troubleshooting section
- **Template errors** → [docs/creating-appliances.md](docs/creating-appliances.md)
- **Deployment issues** → [docs/deployment.md](docs/deployment.md)
- **General help** → [README.md](README.md) FAQ section

## Success Criteria

You're ready to use the registry when:

✅ All core components work
✅ nginx appliance builds and runs
✅ Test server functions
✅ Documentation is clear
✅ No critical errors in logs

Congratulations! 🎉
