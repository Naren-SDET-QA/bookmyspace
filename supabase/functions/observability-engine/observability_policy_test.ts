import { alertIsDue, nextRecoveryState, metricsWindow } from './observability_policy.ts';

Deno.test('alert evaluation honors enabled threshold and cooldown', () => {
  if (alertIsDue({ enabled: false, threshold: 2, value: 5, lastTriggeredAt: null, cooldownSeconds: 60 }, new Date())) throw new Error('disabled alert fired');
  if (alertIsDue({ enabled: true, threshold: 2, value: 1, lastTriggeredAt: null, cooldownSeconds: 60 }, new Date())) throw new Error('below threshold alert fired');
  if (!alertIsDue({ enabled: true, threshold: 2, value: 2, lastTriggeredAt: null, cooldownSeconds: 60 }, new Date())) throw new Error('threshold alert did not fire');
  const recent = new Date(Date.now() - 10_000);
  if (alertIsDue({ enabled: true, threshold: 2, value: 3, lastTriggeredAt: recent, cooldownSeconds: 60 }, new Date())) throw new Error('cooldown ignored');
});

Deno.test('recovery states are bounded and idempotent', () => {
  if (nextRecoveryState('HEALTHY', 0, 3) !== 'RETRYING') throw new Error('retry state missing');
  if (nextRecoveryState('RETRYING', 3, 3) !== 'CIRCUIT_OPEN') throw new Error('circuit did not open');
  if (nextRecoveryState('CIRCUIT_OPEN', 3, 3) !== 'RECOVERING') throw new Error('probe state missing');
  if (nextRecoveryState('HEALTHY', 3, 3) !== 'HEALTHY') throw new Error('healthy state regressed');
});

Deno.test('metrics windows are bounded to supported ranges', () => {
  if (metricsWindow('1h') !== 3600 || metricsWindow('24h') !== 86400 || metricsWindow('7d') !== 604800 || metricsWindow('30d') !== 2592000) throw new Error('window mapping failed');
  if (metricsWindow('unknown') !== 86400) throw new Error('safe default missing');
});
