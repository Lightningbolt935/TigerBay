# 🚀 TigerBay International — Production Azure Deployment Guide

This guide provides step-by-step instructions for deploying the TigerBay International application to **Microsoft Azure** and passing the **GitHub Production Environment** CI/CD pipeline.

---

## 1. Production Architecture Overview

```
                          ┌──────────────────────────┐
                          │   GitHub Actions CI/CD   │
                          │ (.github/workflows/*.yml)│
                          └─────────────┬────────────┘
                                        │
                 ┌──────────────────────┼──────────────────────┐
                 ▼                      ▼                      ▼
        ┌─────────────────┐   ┌──────────────────┐   ┌──────────────────┐
        │  Android Release │   │   iOS IPA Build  │   │  Flutter Web App │
        │  (.apk & .aab)  │   │   (Xcode Bundle) │   │  (WASM / JS SPA) │
        └─────────────────┘   └──────────────────┘   └─────────┬────────┘
                                                               │
                                         ┌─────────────────────┴────────────────────┐
                                         ▼                                          ▼
                              ┌──────────────────────┐                  ┌──────────────────────┐
                              │ Azure Static Web App │  (OR)            │ Azure Container App  │
                              │ (Global Edge / CDN)  │                  │ (Nginx / Linux App)  │
                              └──────────────────────┘                  └──────────────────────┘
```

---

## 2. GitHub Production Environment & Secrets Setup

In your GitHub repository, navigate to:
**Settings** → **Environments** → **New environment** → Name it **`production`**.

Add the following **Environment Secrets** (or Repository Secrets):

| Secret Name | Description | Example / Production Value |
| :--- | :--- | :--- |
| `SUPABASE_URL` | Supabase Project API URL | `https://xxnqlktcbwqhoyezlokv.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase Public Anon JWT Key | `eyJhbGciOiJIUzI1NiIsIn...` |
| `STRIPE_PUBLISHABLE_KEY` | Stripe Live / Test Publishable Key | `pk_live_...` or `pk_test_...` |
| `PAYPAL_CLIENT_ID` | PayPal Live Client ID | `ATw_FSQNby393C2...` |
| `PAYPAL_CLIENT_SECRET` | PayPal Live Secret | `ECgSnr_l-UV086z...` |
| `PAYPAL_MODE` | PayPal Environment Mode | `live` (or `sandbox`) |
| `GOOGLE_WEB_CLIENT_ID` | Google OAuth Web Client ID | `887005202939-...apps.googleusercontent.com` |
| `APP_SCHEME` | Mobile Deep Link Scheme | `io.tigerbay.app` |
| `AZURE_STATIC_WEB_APPS_API_TOKEN` | Azure SWA Deployment Token *(Optional for Web)* | Extracted from Azure Portal |

---

## 3. Deployment Option A: Azure Static Web Apps (Recommended)

Azure Static Web Apps provides global content distribution, custom domain mapping, and free automatic SSL certificates.

### Steps to Deploy:
1. **Create Resource in Azure Portal**:
   - Search for **Static Web Apps** → Click **Create**.
   - Select your Subscription, Resource Group, and Name (e.g. `tigerbay-member-web`).
   - Hosting plan: **Standard** or **Free**.
   - Region: Select your nearest primary region (e.g., `West Europe` or `East US 2`).
   - Deployment source: Select **GitHub** (or **Other**).
2. **Get Deployment Token**:
   - Once created, open the resource overview in the Azure Portal.
   - Click **Manage deployment token** in the top bar.
   - Copy the token value.
3. **Add Secret to GitHub**:
   - In GitHub repository: `Settings` → `Secrets and variables` → `Actions` → Add `AZURE_STATIC_WEB_APPS_API_TOKEN`.
4. **Trigger GitHub Action**:
   - Push to `main` branch or trigger the **Production Release & Azure Deployment** workflow manually from the **Actions** tab.
   - The workflow will automatically compile the optimized Flutter Web release bundle with `staticwebapp.config.json` and deploy it.

---

## 4. Deployment Option B: Azure App Service / Container Apps (Docker)

If hosting as a containerized web application inside a Virtual Network (VNet) or Azure Container Apps:

### Build and Run with Docker:
```bash
# Build production Docker image
docker build -t tigerbay-app:latest \
  --build-arg SUPABASE_URL="https://xxnqlktcbwqhoyezlokv.supabase.co" \
  --build-arg SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1Ni..." \
  --build-arg PAYPAL_MODE="live" .

# Run locally to test
docker run -p 8080:80 tigerbay-app:latest
```

### Push to Azure Container Registry (ACR) & Deploy:
```bash
# Login to ACR
az acr login --name <your_acr_name>

# Tag and push
docker tag tigerbay-app:latest <your_acr_name>.azurecr.io/tigerbay-app:latest
docker push <your_acr_name>.azurecr.io/tigerbay-app:latest

# Deploy to Azure Web App for Containers
az webapp create \
  --resource-group <your_resource_group> \
  --plan <your_app_service_plan> \
  --name tigerbay-portal \
  --deployment-container-image-name <your_acr_name>.azurecr.io/tigerbay-app:latest
```

---

## 5. Custom Domain & SSL on Azure

1. In Azure Portal, navigate to your **Static Web App** or **App Service**.
2. Click **Custom domains** in the sidebar.
3. Click **+ Add** and enter your domain (e.g. `app.tigerbay.com`).
4. In your DNS provider (Cloudflare, GoDaddy, Route53), add a `CNAME` pointing to the Azure hostname (e.g. `*.azurestaticapps.net`).
5. Azure will automatically issue and renew a free TLS/SSL certificate.

---

## 6. Verification Checklist

- [x] Static Analysis passed (`dart analyze lib/ test/` — 0 issues).
- [x] Automated Unit Test Suite passed (`flutter test` — all tests green).
- [x] Safe Environment Resolution implemented (`EnvConfig` supports `--dart-define` and `.env`).
- [x] Android Release APK & AAB builds verified.
- [x] Dockerfile & Nginx configured with SPA routing and security headers.
- [x] Azure Static Web App configuration created (`staticwebapp.config.json`).
- [x] GitHub Actions Production Workflow created (`.github/workflows/production.yml`).
