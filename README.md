# ShaadiSetGo

ShaadiSetGo is a full‑stack wedding services marketplace that connects couples with vetted vendors; the project implements a Node.js + Express backend with MongoDB and a React + TypeScript (Vite) frontend, secure role-based authentication, vendor onboarding and listing, booking and quoting flows, admin and vendor dashboards, file upload handling, data migration and seed scripts, and automated tests for core booking scenarios.

To add this project to the remote GitHub repository `https://github.com/Vishwa-Majmudar/ShaadiSetGo`, you can use the provided `push_to_github.ps1` script. Review the script and run it from the project root.

See `IMPLEMENTATION_SUMMARY.md` for more implementation notes and a testing checklist.

## Docker and automatic deployment

The repository includes a demonstration-ready CI/CD pipeline in
[`ci-cd.yml`](.github/workflows/ci-cd.yml). It uses:

- Docker images for the frontend and backend.
- Docker Compose on an Ubuntu VPS, with MongoDB and persistent volumes.
- GitHub Actions for tests, linting, type checking, image publishing, and deployment.
- GitHub Container Registry (GHCR) as the private image registry.
- SSH from GitHub Actions to the VPS.

After the one-time server setup, every push to `main` follows this flow:

`git push` -> validate -> build Docker images -> publish to GHCR -> SSH to VPS ->
`docker compose pull` -> restart containers -> health check.

This is the "no manual intervention" behavior required for the demo. Pull
requests run validation but do not deploy.

The deployment gate uses the existing backend tests plus the frontend
type-check/build. The repository currently has pre-existing ESLint errors in
unrelated UI files; run `npm run lint` in `frontend` separately when cleaning
those up rather than allowing known lint debt to block this deployment demo.

### 1. Create the Ubuntu server

Create an Ubuntu 22.04/24.04 VPS with a public IP. Open inbound ports 22 and
80 (and 443 later if HTTPS is added). Install Docker Engine and the Compose
plugin using Docker's official installation instructions. Create a deployment
directory, for example `/opt/shaadisetgo`, and clone this repository there:

```bash
sudo mkdir -p /opt/shaadisetgo
sudo chown "$USER":"$USER" /opt/shaadisetgo
git clone https://github.com/Vishwa-Majmudar/ShaadiSetGo.git /opt/shaadisetgo
cd /opt/shaadisetgo
cp .env.production.example .env
nano .env
```

Replace `JWT_SECRET` with a long random value and set `FRONTEND_URL` to the
public website URL. Do not commit `.env`; it is intentionally ignored by Git.

### 2. Create the registry credentials

Create a GitHub fine-grained personal access token with read-only package
access for the repository owner. The workflow's `GITHUB_TOKEN` publishes images;
the VPS needs a separate token to pull private images. On the VPS, test it:

```bash
echo 'YOUR_GHCR_READ_TOKEN' | docker login ghcr.io \
  --username Vishwa-Majmudar --password-stdin
```

The token is not stored in this repository.

### 3. Create GitHub Actions secrets

In GitHub, open **Settings -> Secrets and variables -> Actions -> New
repository secret** and add:

| Secret | Value |
|---|---|
| `VPS_HOST` | VPS public IP or DNS name |
| `VPS_USER` | Linux user that can run Docker |
| `VPS_SSH_KEY` | Private SSH key for that user, including the header/footer |
| `DEPLOY_PATH` | `/opt/shaadisetgo` |
| `GHCR_USERNAME` | `Vishwa-Majmudar` |
| `GHCR_TOKEN` | Read-only GHCR token from step 2 |

Add the same runtime values from the server `.env` as server configuration,
not as GitHub workflow values. This keeps database and JWT secrets off the
GitHub logs.

### 4. Configure SSH on the VPS

Create a dedicated deploy key locally (do not use a personal key):

```bash
ssh-keygen -t ed25519 -C "shaadisetgo-github-actions" -f shaadisetgo_deploy
ssh-copy-id -i shaadisetgo_deploy.pub YOUR_USER@YOUR_SERVER
```

Paste the contents of `shaadisetgo_deploy` into `VPS_SSH_KEY`. Verify the key
works before relying on Actions:

```bash
ssh -i shaadisetgo_deploy YOUR_USER@YOUR_SERVER "docker --version"
```

### 5. Start the first deployment

Push the workflow and configuration changes to `main`:

```bash
git add .
git commit -m "Add Docker CI/CD deployment"
git push origin main
```

Open the repository's **Actions** tab. The `validate` job runs backend tests and
frontend checks. If it passes, `publish` pushes the two images to GHCR and
`deploy` connects to the VPS. The deployment job pulls the commit-specific
images, starts the Compose stack, and checks `http://SERVER/health`.

The site is then available at `http://YOUR_SERVER_IP/`. The frontend and API
share the same origin; Nginx routes `/api` and `/uploads` to the backend.

### 6. Demonstrate automatic updates

Make a visible change, commit, and push:

```bash
git add .
git commit -m "Update homepage banner"
git push origin main
```

No server command is needed. GitHub Actions builds images tagged with the
commit SHA, pulls those exact tags on the VPS, and replaces the running
containers. Refresh the website after the workflow is green.

### 7. GitLab integration option

GitHub Actions is the CI/CD system for this implementation because the source
repository is GitHub. If the assignment explicitly requires GitLab as well,
create a GitLab project and configure a **push mirror** from GitHub to GitLab.
Keep GitHub as the source of truth and do not run two independent deployment
pipelines, which can cause competing releases. GitLab can alternatively be
used only for a mirror/demo while the GitHub Actions workflow remains the
deployment pipeline.

### Important production improvements

For a real public deployment, add HTTPS with a domain and Caddy or Nginx
Certbot, restrict the VPS firewall, use a managed MongoDB service with
authentication and backups, rotate the default admin credentials, and use
GitHub environment protection with an approval gate. The supplied pipeline is
intentionally small and transparent for a classroom Docker/DevOps demo.
