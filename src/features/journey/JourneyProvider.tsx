import { createContext, useContext, type ReactNode } from 'react';
import { getCurrentJourney } from './journeyStore';
import type { CurrentJourney } from './journeyTypes';

const JourneyContext = createContext<CurrentJourney | null>(null);

type JourneyProviderProps = {
  children: ReactNode;
};

export function JourneyProvider({ children }: JourneyProviderProps) {
  const journey = getCurrentJourney();
  return <JourneyContext.Provider value={journey}>{children}</JourneyContext.Provider>;
}

export function useJourney(): CurrentJourney {
  const journey = useContext(JourneyContext);
  if (!journey) {
    throw new Error('useJourney must be used within JourneyProvider');
  }
  return journey;
}
