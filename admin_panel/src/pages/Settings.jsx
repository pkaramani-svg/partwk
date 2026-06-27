import { useState, useEffect } from 'react';
import { fetchGlobalSettings, saveGlobalSettings } from '../services/api';

const Settings = () => {
  const [activeTab, setActiveTab] = useState('content');

  // Content Settings
  const [globalLanguage, setGlobalLanguage] = useState('en');
  const [autoPublish, setAutoPublish] = useState(false);

  // Gamification Settings
  const [streakRequirement, setStreakRequirement] = useState(1);
  const [allowWeekendBreaks, setAllowWeekendBreaks] = useState(false);

  // User Settings
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [allowNewRegistrations, setAllowNewRegistrations] = useState(true);

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadSettings = async () => {
      try {
        const data = await fetchGlobalSettings();
        if (data) {
          if (data.globalLanguage !== undefined) setGlobalLanguage(data.globalLanguage);
          if (data.autoPublish !== undefined) setAutoPublish(data.autoPublish);
          if (data.streakRequirement !== undefined) setStreakRequirement(data.streakRequirement);
          if (data.allowWeekendBreaks !== undefined) setAllowWeekendBreaks(data.allowWeekendBreaks);
          if (data.maintenanceMode !== undefined) setMaintenanceMode(data.maintenanceMode);
          if (data.allowNewRegistrations !== undefined) setAllowNewRegistrations(data.allowNewRegistrations);
        }
      } catch (error) {
        console.error("Failed to load settings:", error);
      } finally {
        setLoading(false);
      }
    };
    loadSettings();
  }, []);

  const saveSettings = async (e) => {
    e.preventDefault();
    try {
      await saveGlobalSettings({
        globalLanguage,
        autoPublish,
        streakRequirement: Number(streakRequirement),
        allowWeekendBreaks,
        maintenanceMode,
        allowNewRegistrations
      });
      alert(`${activeTab.toUpperCase()} Settings saved successfully to Database!`);
    } catch (error) {
      alert(`Failed to save settings: ${error.message}`);
    }
  };

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <h1 className="page-title">Global Settings</h1>
      </div>

      <div style={{ display: 'flex', gap: '24px', alignItems: 'flex-start' }}>
        
        {/* Settings Navigation */}
        <div className="glass-panel" style={{ width: '250px', padding: '16px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <button 
            onClick={() => setActiveTab('content')} 
            style={{ padding: '12px 16px', textAlign: 'left', background: activeTab === 'content' ? 'rgba(255,255,255,0.1)' : 'transparent', border: 'none', borderRadius: '8px', color: activeTab === 'content' ? '#fff' : '#94A3B8', fontWeight: activeTab === 'content' ? 'bold' : 'normal', cursor: 'pointer' }}
          >
            Content & Language
          </button>
          <button 
            onClick={() => setActiveTab('gamification')} 
            style={{ padding: '12px 16px', textAlign: 'left', background: activeTab === 'gamification' ? 'rgba(255,255,255,0.1)' : 'transparent', border: 'none', borderRadius: '8px', color: activeTab === 'gamification' ? '#fff' : '#94A3B8', fontWeight: activeTab === 'gamification' ? 'bold' : 'normal', cursor: 'pointer' }}
          >
            Gamification & Streaks
          </button>
          <button 
            onClick={() => setActiveTab('users')} 
            style={{ padding: '12px 16px', textAlign: 'left', background: activeTab === 'users' ? 'rgba(255,255,255,0.1)' : 'transparent', border: 'none', borderRadius: '8px', color: activeTab === 'users' ? '#fff' : '#94A3B8', fontWeight: activeTab === 'users' ? 'bold' : 'normal', cursor: 'pointer' }}
          >
            User Management & Security
          </button>
        </div>

        {/* Settings Form */}
        <div className="glass-panel" style={{ flex: 1, padding: '32px', maxWidth: '600px' }}>
          <form onSubmit={saveSettings} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
            
            {activeTab === 'content' && (
              <>
                <h2 style={{ color: '#14B8A6', marginBottom: '8px' }}>Content Settings</h2>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Default App Language</label>
                  <select className="input-field" value={globalLanguage} onChange={e => setGlobalLanguage(e.target.value)} style={{ width: '100%' }}>
                    <option value="en">English (EN)</option>
                    <option value="ar">Arabic (AR)</option>
                    <option value="ku">Kurdish (KU)</option>
                  </select>
                </div>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <input type="checkbox" id="autoPublish" checked={autoPublish} onChange={e => setAutoPublish(e.target.checked)} style={{ width: '20px', height: '20px' }} />
                    <label htmlFor="autoPublish" style={{ color: '#fff', fontWeight: 'bold' }}>Auto-publish Books immediately after upload</label>
                  </div>
                </div>
              </>
            )}

            {activeTab === 'gamification' && (
              <>
                <h2 style={{ color: '#8B5CF6', marginBottom: '8px' }}>Gamification Settings</h2>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Minimum chapters read per day for Streak</label>
                  <input type="number" min="1" className="input-field" value={streakRequirement} onChange={e => setStreakRequirement(e.target.value)} style={{ width: '100%' }} />
                </div>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <input type="checkbox" id="weekendBreaks" checked={allowWeekendBreaks} onChange={e => setAllowWeekendBreaks(e.target.checked)} style={{ width: '20px', height: '20px' }} />
                    <label htmlFor="weekendBreaks" style={{ color: '#fff', fontWeight: 'bold' }}>Allow weekend breaks (Streaks won't break on Sat/Sun)</label>
                  </div>
                </div>
              </>
            )}

            {activeTab === 'users' && (
              <>
                <h2 style={{ color: '#F59E0B', marginBottom: '8px' }}>User & Security Settings</h2>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
                    <input type="checkbox" id="newRegs" checked={allowNewRegistrations} onChange={e => setAllowNewRegistrations(e.target.checked)} style={{ width: '20px', height: '20px' }} />
                    <label htmlFor="newRegs" style={{ color: '#fff', fontWeight: 'bold' }}>Allow New User Registrations via the mobile app</label>
                  </div>
                </div>
                <div style={{ padding: '16px', background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.2)', borderRadius: '8px' }}>
                  <h3 style={{ color: '#EF4444', marginBottom: '12px' }}>Danger Zone</h3>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <input type="checkbox" id="maintMode" checked={maintenanceMode} onChange={e => setMaintenanceMode(e.target.checked)} style={{ width: '20px', height: '20px' }} />
                    <label htmlFor="maintMode" style={{ color: maintenanceMode ? '#EF4444' : '#fff', fontWeight: 'bold' }}>Enable Maintenance Mode (Blocks all users from logging in)</label>
                  </div>
                </div>
              </>
            )}

            <button type="submit" className="btn-primary" style={{ marginTop: '16px', padding: '16px', fontSize: '16px' }}>Save {activeTab.charAt(0).toUpperCase() + activeTab.slice(1)} Settings</button>

          </form>
        </div>
      </div>
    </div>
  );
};

export default Settings;
