import { Route, Routes } from 'react-router-dom';
import { DexPage } from './pages/DexPage';
import { HomePage } from './pages/HomePage';
import { JourneyPage } from './pages/JourneyPage';
import { SearchPage } from './pages/SearchPage';
import { TeamPage } from './pages/TeamPage';

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/team" element={<TeamPage />} />
      <Route path="/journey" element={<JourneyPage />} />
      <Route path="/dex" element={<DexPage />} />
      <Route path="/search" element={<SearchPage />} />
    </Routes>
  );
}
