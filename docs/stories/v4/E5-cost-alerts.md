# E5: Cost Alerts

**Epic**: E (Operations) | **Priority**: P2 | **Sprint**: V4 | **Est**: M | **Risk**: L

## User Story
As a System Administrator, I WANT cost alerts, SO THAT I can detect billing anomalies.

## Dependencies
- Cloud Monitoring API access
- Budget thresholds configured in Firebase/GCP

## Acceptance Criteria

### Success Scenario
**GIVEN** daily Cloud Functions cost exceeds $10  
**WHEN** the monitoring function runs  
**THEN** alert email is sent to admin

## Definition of Done
- [ ] Cost monitoring scheduled function
- [ ] Alert threshold configurable
- [ ] Email alerts working
- [ ] Demo: simulate high cost → alert sent

## References
- [Cloud Monitoring](https://cloud.google.com/monitoring)
