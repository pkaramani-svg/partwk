import { Users, BookOpen, Crown, TrendingUp } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import './Dashboard.css';

import { useState, useEffect } from 'react';
import { fetchUsers, fetchBooks } from '../services/api';

// Dynamic chart data will be used instead


const StatCard = ({ title, value, icon: Icon, trend, colorClass }) => (
  <div className="stat-card glass-panel">
    <div className="stat-header">
      <div className={`stat-icon-wrapper ${colorClass}`}>
        <Icon size={24} />
      </div>
      {trend !== null && trend !== undefined && (
        <span className={`stat-trend ${trend >= 0 ? 'positive' : 'negative'}`}>
          {trend >= 0 ? '+' : ''}{trend}%
        </span>
      )}
    </div>
    <div className="stat-info">
      <h3>{value}</h3>
      <p>{title}</p>
    </div>
  </div>
);

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalUsers: 0,
    premiumUsers: 0,
    totalBooks: 0,
    booksFinished: 0,
    chartData: []
  });

  useEffect(() => {
    const loadStats = async () => {
      try {
        const users = await fetchUsers();
        const books = await fetchBooks();
        
        const premiumCount = users.filter(u => u.subscriptionStatus === 'premium' || u.subscriptionStatus === 'pro').length;
        
        let totalFinished = 0;
        users.forEach(u => {
          if (u.completedBooks && Array.isArray(u.completedBooks)) {
            totalFinished += u.completedBooks.length;
          }
        });

        // Calculate Last 7 Days User Growth
        const last7Days = Array.from({length: 7}).map((_, i) => {
          const d = new Date();
          d.setDate(d.getDate() - (6 - i));
          return d;
        });

        const growthData = last7Days.map(date => {
          const startOfDay = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
          const endOfDay = startOfDay + 24 * 60 * 60 * 1000;
          
          const newUsersCount = users.filter(u => {
            if (!u.createdAt) return false;
            const uDate = new Date(u.createdAt.seconds ? u.createdAt.seconds * 1000 : u.createdAt).getTime();
            return uDate >= startOfDay && uDate < endOfDay;
          }).length;
          
          return {
            name: date.toLocaleDateString('en-US', { weekday: 'short' }),
            newUsers: newUsersCount
          };
        });

        setStats({
          totalUsers: users.length,
          premiumUsers: premiumCount,
          totalBooks: books.length,
          booksFinished: totalFinished,
          chartData: growthData
        });
      } catch (error) {
        console.error("Error loading stats:", error);
      }
    };
    loadStats();
  }, []);

  return (
    <div className="dashboard-page">
      <h1 className="page-title">Dashboard Overview</h1>
      
      <div className="stats-grid">
        <StatCard title="Total Users" value={stats.totalUsers.toLocaleString()} icon={Users} trend={null} colorClass="bg-blue" />
        <StatCard title="Premium Subscribers" value={stats.premiumUsers.toLocaleString()} icon={Crown} trend={null} colorClass="bg-amber" />
        <StatCard title="Total Books" value={stats.totalBooks.toLocaleString()} icon={BookOpen} trend={null} colorClass="bg-teal" />
        <StatCard title="Books Finished" value={stats.booksFinished.toLocaleString()} icon={TrendingUp} trend={null} colorClass="bg-green" />
      </div>

      <div className="charts-grid">
        <div className="chart-card glass-panel">
          <div className="chart-header">
            <h3>New User Registrations (Last 7 Days)</h3>
          </div>
          <div className="chart-body">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={stats.chartData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorUsers" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#0D9488" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#0D9488" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <XAxis dataKey="name" stroke="#94A3B8" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#94A3B8" fontSize={12} tickLine={false} axisLine={false} allowDecimals={false} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#131B2E', border: '1px solid #1E293B', borderRadius: '8px', color: '#F8FAFC' }}
                  itemStyle={{ color: '#14B8A6' }}
                />
                <Area type="monotone" dataKey="newUsers" stroke="#0D9488" strokeWidth={3} fillOpacity={1} fill="url(#colorUsers)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
