import { BrowserRouter } from 'react-router-dom';
import { BottomNav } from '../components/BottomNav';
import { DeviceShell } from '../components/layout/DeviceShell';
import { JourneyProvider } from '../features/journey/JourneyProvider';
import { AppRoutes } from './routes';

export function App() {
  return (
    <BrowserRouter>
      <JourneyProvider>
        <DeviceShell>
          <div className="app-shell">
            <main className="app-shell__main">
              <AppRoutes />
            </main>
            <BottomNav />
          </div>
        </DeviceShell>
      </JourneyProvider>
    </BrowserRouter>
  );
}
