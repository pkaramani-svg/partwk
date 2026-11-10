import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import OnlineUsers from './pages/OnlineUsers';
import UsersManagement from './pages/UsersManagement';
import ContentManagement from './pages/ContentManagement';
import PopupManagement from './pages/PopupManagement';
import Settings from './pages/Settings';
import PageUnavailable from './components/PageUnavailable';
import './App.css';

function isAllowedAdminHostname() {
  const host = window.location.hostname.toLowerCase();
  return host === 'admin.partwk.com' || host === 'localhost' || host === '127.0.0.1';
}

function App() {
  if (!isAllowedAdminHostname()) {
    return <PageUnavailable />;
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Layout />}>
          <Route index element={<Dashboard />} />
          <Route path="online" element={<OnlineUsers />} />
          <Route path="users" element={<UsersManagement />} />
          <Route path="content" element={<ContentManagement />} />
          <Route path="popups" element={<PopupManagement />} />
          <Route path="settings" element={<Settings />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
