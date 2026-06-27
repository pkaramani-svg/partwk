import React, { useState, useEffect } from 'react';
import { Users, BookOpen, Headphones, HelpCircle, Activity, Radio, Clock } from 'lucide-react';
import { subscribeToUsers } from '../services/api';
import './OnlineUsers.css';

const OnlineUsers = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = subscribeToUsers((data) => {
      setUsers(data);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  // Filter online users (seen within last 3 minutes or explicitly isOnline: true)
  const isUserOnline = (user) => {
    if (user.isOnline === false) return false;
    if (!user.lastSeen) return false;
    try {
      const lastSeenTime = new Date(user.lastSeen).getTime();
      const now = new Date().getTime();
      // Considered online if activity was within last 3 minutes (180,000 ms)
      return (now - lastSeenTime) < 180000;
    } catch (e) {
      return false;
    }
  };

  const onlineUsers = users.filter(isUserOnline);
  const readingUsers = onlineUsers.filter(u => u.currentActivity?.type === 'reading');
  const listeningUsers = onlineUsers.filter(u => u.currentActivity?.type === 'listening');
  const quizUsers = onlineUsers.filter(u => u.currentActivity?.type === 'quiz');

  const getTimeAgo = (isoString) => {
    if (!isoString) return 'Just now';
    try {
      const diffSecs = Math.floor((new Date().getTime() - new Date(isoString).getTime()) / 1000);
      if (diffSecs < 10) return 'Just now';
      if (diffSecs < 60) return `${diffSecs}s ago`;
      const diffMins = Math.floor(diffSecs / 60);
      return `${diffMins}m ago`;
    } catch (e) {
      return 'Just now';
    }
  };

  return (
    <div className="online-users-page">
      <div className="online-header">
        <h1>
          <Activity size={28} color="#8B5CF6" /> Live App Users & Activity
        </h1>
        <div className="live-badge">
          <div className="pulse-dot"></div> Live Realtime Feed
        </div>
      </div>

      {/* Live Stat Cards */}
      <div className="online-stats-grid">
        <div className="stat-card-online">
          <div className="stat-icon-wrapper green">
            <Radio size={24} />
          </div>
          <div className="stat-info">
            <h3>{loading ? '-' : onlineUsers.length}</h3>
            <p>Active Online Users</p>
          </div>
        </div>

        <div className="stat-card-online">
          <div className="stat-icon-wrapper purple">
            <BookOpen size={24} />
          </div>
          <div className="stat-info">
            <h3>{loading ? '-' : readingUsers.length}</h3>
            <p>Reading Summaries</p>
          </div>
        </div>

        <div className="stat-card-online">
          <div className="stat-icon-wrapper orange">
            <Headphones size={24} />
          </div>
          <div className="stat-info">
            <h3>{loading ? '-' : listeningUsers.length}</h3>
            <p>Listening to Audio</p>
          </div>
        </div>

        <div className="stat-card-online">
          <div className="stat-icon-wrapper teal">
            <HelpCircle size={24} />
          </div>
          <div className="stat-info">
            <h3>{loading ? '-' : quizUsers.length}</h3>
            <p>Taking Quizzes</p>
          </div>
        </div>
      </div>

      {/* Online Users List Table */}
      <div className="section-title-box">
        <h2>Currently Active Users ({onlineUsers.length})</h2>
      </div>

      <div className="users-online-table-container">
        {loading ? (
          <div className="empty-online-state">
            <Activity size={32} className="animate-spin" color="#8B5CF6" />
            <p>Connecting to live Firestore presence feed...</p>
          </div>
        ) : onlineUsers.length === 0 ? (
          <div className="empty-online-state">
            <Users size={36} color="#475569" />
            <p>No active users currently online in the app.</p>
          </div>
        ) : (
          <table className="users-online-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Status</th>
                <th>Current Feature / Screen</th>
                <th>Active Title</th>
                <th>Last Active</th>
              </tr>
            </thead>
            <tbody>
              {onlineUsers.map((user) => {
                const activity = user.currentActivity || {};
                const actType = activity.type || 'browsing';
                
                return (
                  <tr key={user.id}>
                    <td>
                      <div className="user-cell">
                        <div className="user-avatar-circle">
                          {(user.name || user.email || 'U').charAt(0).toUpperCase()}
                        </div>
                        <div className="user-name-box">
                          <span className="name">{user.name || 'User'}</span>
                          <span className="email">{user.email || 'Guest User'}</span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div className="live-badge">
                        <div className="pulse-dot"></div> Online
                      </div>
                    </td>
                    <td>
                      <span className={`activity-badge ${actType}`}>
                        {actType === 'reading' && <BookOpen size={14} />}
                        {actType === 'listening' && <Headphones size={14} />}
                        {actType === 'quiz' && <HelpCircle size={14} />}
                        {actType === 'browsing' && <Activity size={14} />}
                        {activity.screen || 'Using App'}
                      </span>
                    </td>
                    <td>
                      {activity.bookTitle ? (
                        <div className="book-title-chip">
                          <BookOpen size={14} color="#8B5CF6" />
                          {activity.bookTitle}
                        </div>
                      ) : (
                        <span style={{ color: '#64748B', fontSize: '13px' }}>-</span>
                      )}
                    </td>
                    <td>
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', color: '#94A3B8', fontSize: '13px' }}>
                        <Clock size={12} /> {getTimeAgo(user.lastSeen || activity.updatedAt)}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};

export default OnlineUsers;
