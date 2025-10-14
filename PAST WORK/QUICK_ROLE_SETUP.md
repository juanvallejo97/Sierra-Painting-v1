# Quick Role Setup - Console UI Method

**You're already in the right place!**

---

## Step 1: Test setUserRole Function

You're viewing: `setUserRole` function in Cloud Console

### Click the "Test" tab (top right, blue button)

In the test input, paste this JSON:

**For Admin:**
```json
{
  "uid": "yqLJSx5NH1YHKa9WxIOhCrqJcPp1",
  "role": "admin",
  "companyId": "test-company-staging"
}
```

Click **"Run test"**

**Expected Result:**
```json
{
  "success": true,
  "uid": "yqLJSx5NH1YHKa9WxIOhCrqJcPp1",
  "role": "admin",
  "companyId": "test-company-staging"
}
```

---

**For Worker:**
```json
{
  "uid": "d5POlAllCoacEAN5uajhJfzcIJu2",
  "role": "worker",
  "companyId": "test-company-staging"
}
```

Click **"Run test"** again

**Expected Result:**
```json
{
  "success": true,
  "uid": "d5POlAllCoacEAN5uajhJfzcIJu2",
  "role": "worker",
  "companyId": "test-company-staging"
}
```

---

## Alternative: Cloud Shell (What You Started)

I can see you started a curl command in Cloud Shell. Complete it:

```bash
curl -X POST "https://setuserrole-271985878317.us-east4.run.app" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"data":{"uid":"yqLJSx5NH1YHKa9WxIOhCrqJcPp1","role":"admin","companyId":"test-company-staging"}}'
```

**Note:** Callable functions need `{"data": {...}}` wrapper.

For worker:
```bash
curl -X POST "https://setuserrole-271985878317.us-east4.run.app" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"data":{"uid":"d5POlAllCoacEAN5uajhJfzcIJu2","role":"worker","companyId":"test-company-staging"}}'
```

---

## Once Roles Are Set

**Next steps:**
1. ✅ Verify roles set (check response shows success: true)
2. ✅ Check Firestore for company/job/assignment setup
3. ✅ Run 6 smoke tests via Flutter app
4. ✅ Post results back

---

**Recommendation:** Use the **Test tab** in the Console (easier). It's the blue "Test" button at the top right of your current screen.
