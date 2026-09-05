export type AlertInput = { enabled: boolean; threshold: number; value: number; lastTriggeredAt: Date | null; cooldownSeconds: number };

export function alertIsDue(input: AlertInput, now: Date): boolean {
  if (!input.enabled || input.value < input.threshold) return false;
  if (!input.lastTriggeredAt) return true;
  return now.getTime() - input.lastTriggeredAt.getTime() >= Math.max(input.cooldownSeconds, 0) * 1000;
}

export function nextRecoveryState(state: string, attempts: number, maxRetries: number): string {
  if (state === 'HEALTHY') return attempts < maxRetries ? 'RETRYING' : 'HEALTHY';
  if (state === 'RETRYING') return attempts >= maxRetries ? 'CIRCUIT_OPEN' : 'RETRYING';
  if (state === 'CIRCUIT_OPEN') return 'RECOVERING';
  if (state === 'RECOVERING') return 'HEALTHY';
  return 'DEGRADED';
}

export function metricsWindow(value: string): number {
  return ({ '1h': 3600, '24h': 86400, '7d': 604800, '30d': 2592000 } as Record<string, number>)[value] ?? 86400;
}
