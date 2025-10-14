# Sierra Painting - Deployment Instructions
# Created: 2023-10-04

deployment:
  project_name: "Sierra Painting"
  version: "v1.0.0-production"
  
  # Prerequisites
  prerequisites:
    - Flutter SDK 3.10.0 or higher
    - Firebase CLI 12.0.0 or higher
    - Git
    - Node.js 18.x or higher
    - flutterfire CLI
    
  # Firebase Configuration
  firebase:
    project_id: "sierra-painting" # To be provided during setup
    apps:
      - platform: android
        package_name: "com.sierra.painting"
      - platform: ios
        bundle_id: "com.sierra.painting"
      - platform: web
        hosting_target: "build/web"

  # Environment Setup
  environment:
    - Run setup script: ./scripts/setup_env.sh
    - Configure .env file: ./scripts/configure_env.sh
    - Verify configuration: ./scripts/verify_config.sh
    
  # Dependency Resolution
  dependencies:
    fix_strategy: "Pin specific versions of firebase packages"
    actions:
      - Update pubspec.yaml with compatible firebase versions
      - Run flutter pub get to verify dependencies
      - Run flutter pub upgrade --major-versions if needed
    
  # Build Steps
  build:
    web:
      command: "flutter build web --release --dart-define-from-file=.env"
      output: "build/web"
    android:
      command: "flutter build appbundle --release --dart-define-from-file=.env"
      output: "build/app/outputs/bundle/release/app-release.aab"
    ios:
      command: "flutter build ipa --release --dart-define-from-file=.env"
      output: "build/ios/archive"
      
  # Deployment Steps
  deploy:
    web:
      command: "firebase deploy --only hosting"
    functions:
      command: "firebase deploy --only functions"
    firestore:
      command: "firebase deploy --only firestore:rules,firestore:indexes"
    storage:
      command: "firebase deploy --only storage"
    
  # Post-Deployment Verification
  verification:
    - Verify web deployment: Open https://{PROJECT_ID}.web.app
    - Test authentication flows
    - Test core business features
    - Verify Stripe integration
    - Check performance monitoring

  # Feature Flags
  feature_flags:
    core:
      - FEATURE_CLOCK_IN_ENABLED: true
      - FEATURE_CLOCK_OUT_ENABLED: true
      - FEATURE_JOBS_TODAY_ENABLED: true
    v2:
      - FEATURE_CREATE_QUOTE_ENABLED: true 
      - FEATURE_MARK_PAID_ENABLED: true
      - FEATURE_STRIPE_CHECKOUT_ENABLED: true

  # Monitoring & Analytics
  monitoring:
    performance: true
    error_tracking: true
    debug_logging: false
    log_level: "info"
    
  # Vertex AI Integration
  vertex_ai:
    enabled: true
    setup:
      - Enable Vertex AI API in Google Cloud Console
      - Configure Firebase AI Logic SDK
