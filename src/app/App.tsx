import { BrowserRouter } from 'react-router-dom';
import { BottomNav } from '../components/BottomNav';
import { AppRoutes } from './routes';

export function App() {
  return (
    <BrowserRouter>
      <div className="app-shell">
        <main className="app-shell__main">
          <AppRoutes />
        </main>
        <BottomNav />
      </div>
    </BrowserRouter>
  );
}
