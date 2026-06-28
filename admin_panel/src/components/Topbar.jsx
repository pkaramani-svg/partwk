import { useState, useRef, useEffect } from 'react';
import { Bell, Search, UserCircle, LogOut, Settings, User } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import './Topbar.css';

const Topbar = ({ searchTerm, setSearchTerm }) => {
  const [showNotifs, setShowNotifs] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const [adminUser, setAdminUser] = useState({ name: 'Admin', email: 'admin@partwk.com' });
  const navigate = useNavigate();
  const notifRef = useRef(null);
  const profileRef = useRef(null);

  useEffect(() => {
    import('../services/api').then(({ fetchUsers }) => {
      fetchUsers().then(users => {
        const admin = users.find(u => u.role === 'admin');
        if (admin) {
          setAdminUser({ name: admin.name || 'Admin User', email: admin.email });
        }
      });
    });
  }, []);

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (notifRef.current && !notifRef.current.contains(event.target)) {
        setShowNotifs(false);
      }
      if (profileRef.current && !profileRef.current.contains(event.target)) {
        setShowProfile(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);
  return (
    <header className="topbar glass-panel">
      <div className="search-container">
        <Search size={18} className="search-icon" />
        <input 
          type="text" 
          placeholder="Search..." 
          className="search-input" 
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
      </div>
      <div className="topbar-actions">
        {/* Notifications */}
        <div className="relative-container" ref={notifRef} style={{ position: 'relative' }}>
          <button className="icon-btn" onClick={() => setShowNotifs(!showNotifs)}>
            <Bell size={20} />
            <span className="badge">3</span>
          </button>
          
          {showNotifs && (
            <div className="dropdown-menu glass-panel" style={{ position: 'absolute', top: '100%', right: 0, marginTop: '8px', width: '300px', padding: '16px', borderRadius: '12px', zIndex: 50 }}>
              <h3 style={{ fontSize: '14px', fontWeight: 'bold', marginBottom: '12px', color: '#94A3B8' }}>Notifications</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '8px' }}>
                <p style={{ color: '#94A3B8', fontSize: '13px', margin: 0, textAlign: 'center' }}>No new notifications</p>
              </div>
            </div>
          )}
        </div>

        {/* Profile */}
        <div className="relative-container" ref={profileRef} style={{ position: 'relative' }}>
          <div className="profile-btn" onClick={() => setShowProfile(!showProfile)} style={{ cursor: 'pointer' }}>
            <UserCircle size={28} />
            <div className="profile-info">
              <span className="profile-name">{adminUser.name}</span>
              <span className="profile-role">Superuser</span>
            </div>
          </div>

          {showProfile && (
            <div className="dropdown-menu glass-panel" style={{ position: 'absolute', top: '100%', right: 0, marginTop: '8px', width: '200px', padding: '8px', borderRadius: '12px', zIndex: 50 }}>
              <div style={{ padding: '8px 12px', borderBottom: '1px solid rgba(255,255,255,0.1)', marginBottom: '8px' }}>
                <p style={{ margin: 0, fontWeight: 'bold', fontSize: '14px' }}>{adminUser.name}</p>
                <p style={{ margin: 0, fontSize: '12px', color: '#94A3B8' }}>{adminUser.email}</p>
              </div>
              <button 
                onClick={() => { setShowProfile(false); navigate('/settings'); }}
                style={{ width: '100%', display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 12px', background: 'transparent', border: 'none', color: '#fff', textAlign: 'left', cursor: 'pointer', borderRadius: '6px' }}
                onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <Settings size={16} /> Account Settings
              </button>
              <button 
                onClick={async () => {
                  sessionStorage.removeItem('admin_2fa_verified');
                  sessionStorage.removeItem('admin_email');
                  const { getAuth, signOut } = await import('firebase/auth');
                  await signOut(getAuth());
                  navigate('/login');
                }}
                style={{ width: '100%', display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 12px', background: 'transparent', border: 'none', color: '#EF4444', textAlign: 'left', cursor: 'pointer', borderRadius: '6px' }}
                onMouseOver={(e) => e.currentTarget.style.background = 'rgba(239, 68, 68, 0.1)'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <LogOut size={16} /> Sign Out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};

export default Topbar;
