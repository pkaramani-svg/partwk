import { useState } from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, Users, BookOpen, Settings, Activity } from 'lucide-react';
import './Sidebar.css';

const Sidebar = () => {
  return (
    <aside className="sidebar glass-panel">
      <div className="sidebar-header">
        <div className="logo-icon">
          <BookOpen color="white" size={24} />
        </div>
        <h2 className="text-gradient">Partwk Admin</h2>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
          <LayoutDashboard size={20} />
          <span>Dashboard</span>
        </NavLink>
        <NavLink to="/online" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
          <Activity size={20} color="#10B981" />
          <span>Live Online</span>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', backgroundColor: '#10B981', marginLeft: 'auto', boxShadow: '0 0 6px #10B981' }}></span>
        </NavLink>
        <NavLink to="/users" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
          <Users size={20} />
          <span>Users</span>
        </NavLink>
        <NavLink to="/content" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
          <BookOpen size={20} />
          <span>Content</span>
        </NavLink>
        <div className="nav-divider"></div>
        <NavLink to="/settings" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
          <Settings size={20} />
          <span>Settings</span>
        </NavLink>
      </nav>
    </aside>
  );
};

export default Sidebar;
