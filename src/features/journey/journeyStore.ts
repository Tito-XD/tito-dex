import { mockJourney } from '../../data/mockJourney';
import type { CurrentJourney } from './journeyTypes';

/** Phase 2 mock store — local persistence comes in Phase 3. */
export function getCurrentJourney(): CurrentJourney {
  return mockJourney;
}
