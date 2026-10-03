/** Task delivery OTP — tighter than the global 300/min. */
export const taskOtpRateLimit = { max: 10, timeWindow: '10 minutes' } as const;

/** Shared S2S token endpoints — brute-force and flood bound. */
export const serviceRouteRateLimit = { max: 60, timeWindow: '1 minute' } as const;

/** Activation start — roster enumeration / SMS cost bound. */
export const activationStartRateLimit = { max: 5, timeWindow: '10 minutes' } as const;

/** Activation verify — OTP brute-force bound. */
export const activationVerifyRateLimit = { max: 10, timeWindow: '10 minutes' } as const;

/** Sync pull: reassigned-away ids. Unbounded arrays blow the courier radio. */
export const REMOVED_TASK_IDS_LIMIT = 200;
