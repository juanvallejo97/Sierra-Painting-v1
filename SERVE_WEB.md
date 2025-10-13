# Serve Flutter Web App - Quick Guide

## ✅ App Currently Running

**URL:** http://localhost:9000

The app is currently served and ready for testing!

---

## 🚀 Future Deployment Commands

### **Option 1: Simple npm command (Recommended)**
```bash
npm run serve
```
- Uses port 9000 by default
- Opens browser automatically
- Serves existing build (must build first)

### **Option 2: Build + Serve Staging**
```bash
npm run serve:staging
```
- Copies `.env.staging` to `.env`
- Builds release web app
- Serves on port 9000

### **Option 3: Auto-port (PowerShell Script)**
```bash
pwsh ./scripts/serve_web.ps1
```
**Features:**
- ✅ Auto-finds available port (9000-9009)
- ✅ Builds if needed
- ✅ Opens browser
- ✅ Handles port conflicts

**With custom port:**
```bash
pwsh ./scripts/serve_web.ps1 8080
```

**Force rebuild:**
```bash
pwsh ./scripts/serve_web.ps1 -Build
```

### **Option 4: Bash Script (Linux/Mac/Git Bash)**
```bash
bash ./scripts/serve_web.sh 9000
```

### **Option 5: Manual (Current Method)**
```bash
# 1. Build
flutter build web --release

# 2. Serve
cd build/web
npx http-server -p 9000 -o --cors
```

---

## 🔧 Port Management

### **If Port is Blocked:**

The PowerShell script (`serve_web.ps1`) automatically finds the next available port:
- Tries 9000
- If blocked → tries 9001
- If blocked → tries 9002
- ... up to 9009

### **Manual Port Check (Windows):**
```powershell
# Check what's using port 9000
netstat -ano | findstr :9000

# Kill process by PID
taskkill /PID <PID> /F
```

### **Manual Port Check (Linux/Mac):**
```bash
# Check what's using port 9000
lsof -i :9000

# Kill process
kill -9 <PID>
```

---

## 📋 Common Workflows

### **Staging Validation Testing**
```bash
# 1. Copy staging config
cp .env.staging .env

# 2. Build release
flutter build web --release

# 3. Serve
npm run serve
```

### **Local Development Testing**
```bash
# Use local config (App Check disabled)
cp .env .env

# Build dev mode (faster)
flutter build web

# Serve
npx http-server build/web -p 9000 -o
```

### **Quick Rebuild & Serve**
```bash
flutter build web --release && npm run serve
```

---

## 🛠️ Troubleshooting

### **"This site can't be reached"**

**Cause:** Server not started or wrong port

**Fix:**
1. Check server is running: `netstat -ano | findstr :9000`
2. If not running: `npm run serve`
3. If port blocked: `pwsh ./scripts/serve_web.ps1` (auto-finds free port)

### **"ERR_CONNECTION_REFUSED"**

**Cause:** Server died or not listening

**Fix:**
1. Restart server: `npm run serve`
2. Check build exists: `ls build/web/index.html`
3. If no build: `flutter build web --release`

### **App loads but shows errors**

**Cause:** Wrong environment config

**Fix:**
1. Check `.env` file has correct `ENABLE_APP_CHECK` and `RECAPTCHA_V3_SITE_KEY`
2. For staging: `cp .env.staging .env`
3. Rebuild: `flutter build web --release`
4. Serve: `npm run serve`

### **Port already in use**

**Cause:** Previous server still running

**Fix (Auto):**
```bash
pwsh ./scripts/serve_web.ps1  # Finds next free port
```

**Fix (Manual):**
```bash
# Kill process on port 9000 (Windows)
netstat -ano | findstr :9000
taskkill /PID <PID> /F

# Kill process on port 9000 (Linux/Mac)
lsof -i :9000
kill -9 <PID>
```

---

## 📝 Test User Credentials

**Check Firebase Console for UIDs:**
- **Worker:** d5POlAllCoacEAN5uajhJfzcIJu2
- **Admin:** yqLJSx5NH1YHKa9WxIOhCrqJcPp1

**To find email/password:**
1. Go to: https://console.firebase.google.com/project/sierra-painting-staging/authentication/users
2. Search by UID
3. Email shown in table
4. Reset password if needed

**Or check local test credentials if created**

---

## 🎯 Current Session

**Running:** http://localhost:9000
**Environment:** Staging (App Check enabled)
**Build:** Release
**Ready for:** Validation Tests 1-5

Navigate to http://localhost:9000 and login to begin testing!
