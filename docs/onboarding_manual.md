# Manual Employee Onboarding Guide

**Last Updated:** 2025-10-15
**Status:** Active (Phone-based invite not yet implemented)

## Overview

This document provides step-by-step instructions for manually onboarding new employees to the Sierra Painting system. Phone-based invitation with SMS deep links is planned for a future release.

## Prerequisites

- Admin or Manager role in Sierra Painting
- Employee's phone number (E.164 format, e.g., +14155551234)
- Employee's role assignment (Worker, Staff, Manager, or Admin)

## Step-by-Step Process

### 1. Add Employee to System

1. Navigate to **Admin Dashboard** → **Employees**
2. Click **"Add Employee (manual)"** button
3. Fill in employee details:
   - **Full Name** (required)
   - **Phone Number** (required, E.164 format)
   - **Role** (required): Select Worker, Staff, Manager, or Admin
   - **Status**: Set to "Invited" initially
4. Click **"Save"** to create the employee record

### 2. Share Login Credentials Manually

Since automated phone invites are not yet available, you must share login information manually:

#### Option A: In-Person Setup
1. Have the employee open the Sierra Painting app on their device
2. Guide them through creating an account using their phone number
3. Verify their phone number via SMS code
4. Once verified, their account will be automatically linked to the employee record

#### Option B: Email/Text Instructions
Send the following template to the employee:

```
Welcome to Sierra Painting!

To get started:
1. Download the Sierra Painting app (or visit [app URL])
2. Click "Sign Up" or "Create Account"
3. Enter your phone number: [EMPLOYEE_PHONE]
4. Verify with the SMS code you receive
5. Complete your profile

Your role: [EMPLOYEE_ROLE]

Contact your manager if you have questions.
```

### 3. Verify Employee Activation

1. After the employee signs up, their status should change from "Invited" to "Active"
2. Verify the employee can log in and see appropriate features for their role:
   - **Workers**: Timeclock, Schedule, Job History
   - **Staff**: Workers' features + Reports
   - **Managers**: Staff features + Employee Management, Job Assignment
   - **Admins**: All features + Company Settings

### 4. Assign Jobs (For Workers)

Once activated:
1. Navigate to **Admin Dashboard** → **Jobs**
2. Select a job and click **"Assign Workers"**
3. Select the employee and set shift times
4. Employee will see the assignment in their Schedule view

## Troubleshooting

### Employee Status Stuck on "Invited"

**Cause:** Employee hasn't completed account creation or phone verification.

**Solution:**
1. Confirm the employee used the exact phone number in the system (including country code)
2. Check that phone verification SMS was received
3. If needed, delete the employee record and recreate with correct phone number

### Employee Can't See Assigned Jobs

**Cause:** Role permissions or company ID mismatch.

**Solution:**
1. Verify employee's role in **Employees** list
2. Check that employee authenticated with correct phone number
3. Use Firestore console to verify `companyId` custom claim matches

### Employee Sees Wrong Features

**Cause:** Role not properly set in custom claims.

**Solution:**
1. Delete and recreate the employee record
2. Have employee log out and log back in to refresh claims
3. Verify custom claims in Firebase Auth console

## Security Notes

- **Phone Number Format:** Must be E.164 (e.g., +14155551234) for Firebase Auth compatibility
- **Role Assignment:** Cannot be changed by employee - only by Admins/Managers
- **Company Isolation:** Employees can only see data for their assigned company
- **Custom Claims:** Role and companyId are set server-side via Cloud Functions

## Future Enhancements

The following features are planned for automated onboarding:

- **SMS Invitation:** Send SMS with deep link to download app
- **One-Time Codes:** Generate secure invite codes
- **Self-Service Profile:** Allow employees to complete profile after initial setup
- **Onboarding Checklist:** Guided tour for new employees

## Related Documentation

- [Employee Management](/docs/employee_management.md)
- [Role-Based Access Control](/PAST WORK/docs/ARCHITECTURE.md#rbac)
- [Firestore Security Rules](/firestore.rules)
- [Phone Authentication](https://firebase.google.com/docs/auth/web/phone-auth)

## Support

For technical issues with manual onboarding:
- Contact: dev@sierrapainting.com
- Internal Slack: #sierra-painting-support
- Firebase Console: [Link to project]

---

**Note:** This is a temporary manual process. Automated phone-based invites are tracked in ticket **CLD-CHK-PHONE-ONBOARDING-002** for future implementation.
