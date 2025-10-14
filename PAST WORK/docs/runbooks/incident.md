# Incident Runbook
## Triage
1. Check Firebase Status + Crashlytics spikes
2. Review recent deploys (Functions + Web/Android)
3. Roll back if needed (see `deployment_and_rollbacks.yaml`)

## Common Issues
- Web boot failing: check index loader + App Check keys.
- Android taps not working: ensure mobile scaffold used (see `core/platform.dart`).
- Tests flaking on Windows: pin TEMP/TMP, run serial.