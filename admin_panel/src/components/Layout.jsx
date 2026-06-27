import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Topbar from './Topbar';
import './Layout.css';

const Layout = () => {
  const [searchTerm, setSearchTerm] = useState('');

  return (
    <div className="app-layout">
      <Sidebar />
      <div className="main-wrapper">
        <Topbar searchTerm={searchTerm} setSearchTerm={setSearchTerm} />
        <main className="content-area">
          <Outlet context={[searchTerm, setSearchTerm]} />
        </main>
      </div>
    </div>
  );
};

export default Layout;
