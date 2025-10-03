/**
 * Deployment Configuration for Cloud Functions
 * 
 * Defines region and minInstances settings per environment
 * to support canary deployments and cold start optimization.
 */

export interface FunctionDeploymentConfig {
  minInstances: number;
  maxInstances: number;
  region: string;
  memory?: '128MB' | '256MB' | '512MB' | '1GB' | '2GB' | '4GB' | '8GB';
  timeoutSeconds?: number;
}

export const DEPLOYMENT_CONFIG: Record<string, FunctionDeploymentConfig> = {
  // Critical functions - always warm, low latency required
  clockIn: {
    minInstances: 1,
    maxInstances: 20,
    region: 'us-central1',
    memory: '256MB',
    timeoutSeconds: 30,
  },
  createLead: {
    minInstances: 1,
    maxInstances: 10,
    region: 'us-central1',
    memory: '256MB',
    timeoutSeconds: 30,
  },
  markPaidManual: {
    minInstances: 1,
    maxInstances: 10,
    region: 'us-central1',
    memory: '256MB',
    timeoutSeconds: 30,
  },
  
  // Auth triggers - moderate traffic
  onUserCreate: {
    minInstances: 0,
    maxInstances: 5,
    region: 'us-central1',
    memory: '256MB',
    timeoutSeconds: 60,
  },
  onUserDelete: {
    minInstances: 0,
    maxInstances: 5,
    region: 'us-central1',
    memory: '256MB',
    timeoutSeconds: 60,
  },
  
  // Webhook handlers
  stripeWebhook: {
    minInstances: 0,
    maxInstances: 10,
    region: 'us-central1',
    memory: '256MB',
    timeoutSeconds: 30,
  },
  
  // Health checks
  healthCheck: {
    minInstances: 0,
    maxInstances: 5,
    region: 'us-central1',
    memory: '128MB',
    timeoutSeconds: 10,
  },
};

/**
 * Get deployment config for a function by name
 * Returns default config if function not found
 */
export function getDeploymentConfig(functionName: string): FunctionDeploymentConfig {
  return DEPLOYMENT_CONFIG[functionName] || {
    minInstances: 0,
    maxInstances: 10,
    region: 'us-central1',
    memory: '256MB',
    timeoutSeconds: 60,
  };
}
