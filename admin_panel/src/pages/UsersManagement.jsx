import { useState, useEffect } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Trash2, CheckCircle, XCircle, X, Edit2, Key, BarChart2, Plus, ArrowUp, ArrowDown } from 'lucide-react';
import './UsersManagement.css';
import { fetchUsers, subscribeToUsers, fetchBooks, updateUserStatus, sendPasswordResetEmail, createNewUserManually, deleteUser } from '../services/api';

const formatDateTimeLocal = (isoString) => {
  if (!isoString) return '';
  try {
    const d = new Date(isoString);
    if (isNaN(d.getTime())) return '';
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  } catch (e) {
    return '';
  }
};

const UsersManagement = () => {
  const [searchTerm, setSearchTerm] = useOutletContext();
  const [users, setUsers] = useState([]);
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Sorting State
  const [sortField, setSortField] = useState('name');
  const [sortDirection, setSortDirection] = useState('asc');

  const handleSort = (field) => {
    if (sortField === field) {
      setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };
  
  // Tabs: 'customers' or 'admins'
  const [activeTab, setActiveTab] = useState('customers');

  // Modals
  const [showEditModal, setShowEditModal] = useState(false);
  const [showStatsModal, setShowStatsModal] = useState(false);
  const [showAddUserModal, setShowAddUserModal] = useState(false);
  
  const [selectedUser, setSelectedUser] = useState(null);

  // Form State for Edit
  const [editForm, setEditForm] = useState({ phone: '', address: '', role: 'user', subscriptionStatus: 'free', status: 'active', familyMembers: '' });
  
  // Form State for Add User
  const [addUserForm, setAddUserForm] = useState({ name: '', email: '', password: '', role: 'user', subscriptionStatus: 'free' });
  const [isAddingUser, setIsAddingUser] = useState(false);

  const loadData = async () => {
    try {
      const [usersData, booksData] = await Promise.all([fetchUsers(), fetchBooks()]);
      setUsers(usersData);
      setBooks(booksData);
    } catch (error) {
      console.error("Error fetching data:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    const unsub = subscribeToUsers((data) => {
      setUsers(data);
    });
    return () => unsub();
  }, []);

  const isUserOnline = (u) => {
    if (u.isOnline === false) return false;
    if (!u.lastSeen) return false;
    try {
      return (new Date().getTime() - new Date(u.lastSeen).getTime()) < 180000;
    } catch (e) {
      return false;
    }
  };

  const getFamilyOwner = (userEmail) => {
    if (!userEmail) return null;
    return users.find(u => 
      (u.subscriptionStatus === 'premium' || u.subscriptionStatus === 'pro' || u.role === 'admin') && 
      u.familyMembers?.includes(userEmail)
    );
  };

  const openEditModal = (user) => {
    setSelectedUser(user);
    setEditForm({
      phone: user.phone || '',
      address: user.address || '',
      role: user.role || 'user',
      subscriptionStatus: user.subscriptionStatus || 'free',
      status: user.status || 'active',
      familyMembers: user.familyMembers ? user.familyMembers.join(', ') : '',
      subscriptionStartDate: user.subscriptionStartDate || '',
      subscriptionExpiryDate: user.subscriptionExpiryDate || ''
    });
    setShowEditModal(true);
  };

  const openStatsModal = (user) => {
    setSelectedUser(user);
    setShowStatsModal(true);
  };

  const handlePasswordReset = async (email) => {
    if (window.confirm(`Send password reset email to ${email}?`)) {
      try {
        await sendPasswordResetEmail(email);
        alert('Password reset email sent!');
      } catch (error) {
        alert('Failed to send reset email. Ensure Firebase Auth is configured properly.');
      }
    }
  };

  const handleDeleteUser = async (user) => {
    if (window.confirm(`Are you sure you want to completely delete ${user.email}? This action cannot be undone.`)) {
      try {
        await deleteUser(user.id);
        alert('User successfully deleted from database.');
        loadData();
      } catch (error) {
        alert('Failed to delete user: ' + error.message);
      }
    }
  };

  const saveUserEdits = async (e) => {
    e.preventDefault();
    try {
      const payload = { ...editForm };
      if (typeof payload.familyMembers === 'string') {
        payload.familyMembers = payload.familyMembers.split(',').map(s => s.trim().toLowerCase()).filter(s => s.length > 0);
      }
      
      if (payload.subscriptionStatus === 'premium') {
        if (selectedUser.subscriptionStatus !== 'premium' || !payload.subscriptionStartDate) {
          const start = new Date();
          const expiry = new Date();
          expiry.setFullYear(start.getFullYear() + 1);
          payload.subscriptionStartDate = start.toISOString();
          payload.subscriptionExpiryDate = expiry.toISOString();
        }
      } else {
        payload.subscriptionStartDate = null;
        payload.subscriptionExpiryDate = null;
      }
      
      await updateUserStatus(selectedUser.id, payload);
      setShowEditModal(false);
      loadData();
    } catch (error) {
      alert("Failed to update user.");
    }
  };

  const handleAddUser = async (e) => {
    e.preventDefault();
    setIsAddingUser(true);
    try {
      await createNewUserManually(addUserForm);
      setShowAddUserModal(false);
      setAddUserForm({ name: '', email: '', password: '', role: 'user', subscriptionStatus: 'free' });
      alert("User successfully created!");
      loadData();
    } catch (error) {
      console.error(error);
      alert(`Failed to create user: ${error.message}`);
    } finally {
      setIsAddingUser(false);
    }
  };

  const getBookTitle = (bookId) => {
    if (!bookId) return 'Unknown Book';
    // Strip trailing language suffix (_en, _ar, _ku) if present
    const cleanId = bookId.replace(/_(en|ku|ar)$/, '');
    const b = books.find(b => b.id === cleanId);
    if (!b) return 'Unknown Book';
    return b.title?.en || b.title?.ku || b.title?.ar || 'Untitled';
  };

  const seedDefaultAdmin = async () => {
    setIsAddingUser(true);
    try {
      await createNewUserManually({
        name: 'System Admin',
        email: 'admin@partwk.com',
        password: 'password123',
        role: 'admin'
      });
      alert("Default admin (admin@partwk.com) created! You can now edit their details and reset their password.");
      loadData();
    } catch (error) {
      console.error(error);
      alert(`Failed to create default admin: ${error.message}`);
    } finally {
      setIsAddingUser(false);
    }
  };

  // Filter based on Tab AND Search
  const filteredUsers = users.filter(user => {
    const matchesSearch = (user.name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
                          (user.email || '').toLowerCase().includes(searchTerm.toLowerCase());
    
    const role = user.role || 'user';
    const isCustomer = role === 'user';
    const isAdmin = role === 'admin' || role === 'editor';
    
    if (activeTab === 'customers') return matchesSearch && isCustomer;
    if (activeTab === 'admins') return matchesSearch && isAdmin;
    return false;
  });

  const sortedUsers = [...filteredUsers].sort((a, b) => {
    if (!sortField) return 0;
    let aVal = a[sortField];
    let bVal = b[sortField];

    if (sortField === 'name') {
      aVal = (a.name || '').toLowerCase();
      bVal = (b.name || '').toLowerCase();
    } else if (sortField === 'email') {
      aVal = (a.email || '').toLowerCase();
      bVal = (b.email || '').toLowerCase();
    } else if (sortField === 'role') {
      aVal = (a.role || 'user').toLowerCase();
      bVal = (b.role || 'user').toLowerCase();
    } else if (sortField === 'plan') {
      aVal = (a.subscriptionStatus || 'free').toLowerCase();
      bVal = (b.subscriptionStatus || 'free').toLowerCase();
    } else if (sortField === 'joined') {
      const getVal = (u) => {
        if (!u.createdAt) return 0;
        if (u.createdAt.seconds) return u.createdAt.seconds * 1000;
        return new Date(u.createdAt).getTime();
      };
      aVal = getVal(a);
      bVal = getVal(b);
    }

    if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1;
    if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1;
    return 0;
  });

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <h1 className="page-title">Users Management</h1>
        <div className="header-actions">
          <input 
            type="text" 
            placeholder="Search users..." 
            className="input-field" 
            style={{ width: '300px' }}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
          <button className="btn-primary" onClick={() => setShowAddUserModal(true)}>
            <Plus size={18} />
            Add New User
          </button>
        </div>
      </div>

      <div style={{ display: 'flex', gap: '16px', marginBottom: '24px', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
        <button 
          onClick={() => setActiveTab('customers')} 
          style={{ background: 'transparent', border: 'none', borderBottom: activeTab === 'customers' ? '2px solid #14B8A6' : '2px solid transparent', color: activeTab === 'customers' ? '#14B8A6' : '#94A3B8', padding: '12px 24px', fontSize: '16px', fontWeight: 'bold', cursor: 'pointer' }}
        >
          Customer Users
        </button>
        <button 
          onClick={() => setActiveTab('admins')} 
          style={{ background: 'transparent', border: 'none', borderBottom: activeTab === 'admins' ? '2px solid #8B5CF6' : '2px solid transparent', color: activeTab === 'admins' ? '#8B5CF6' : '#94A3B8', padding: '12px 24px', fontSize: '16px', fontWeight: 'bold', cursor: 'pointer' }}
        >
          Admin Superusers
        </button>
      </div>

      <div className="glass-panel table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th onClick={() => handleSort('name')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  User
                  {sortField === 'name' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('email')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Email
                  {sortField === 'email' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('role')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Role
                  {sortField === 'role' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('plan')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Plan
                  {sortField === 'plan' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('joined')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Joined Date
                  {sortField === 'joined' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan="6" style={{textAlign: 'center', padding: '20px'}}>Loading users...</td></tr>
            ) : sortedUsers.length === 0 ? (
              <tr>
                <td colSpan="6" style={{textAlign: 'center', padding: '40px 20px'}}>
                  <p style={{ marginBottom: '16px', color: '#94A3B8' }}>No {activeTab} found in the database.</p>
                  {activeTab === 'admins' && (
                    <button className="btn-primary" onClick={seedDefaultAdmin} disabled={isAddingUser} style={{ margin: '0 auto' }}>
                      {isAddingUser ? 'Creating Admin...' : 'Generate Default System Admin'}
                    </button>
                  )}
                </td>
              </tr>
            ) : sortedUsers.map((user) => (
              <tr key={user.id}>
                <td>
                  <div className="user-cell">
                    <div style={{ position: 'relative' }}>
                      <div className="avatar" style={{ background: user.role === 'admin' ? 'linear-gradient(135deg, #8B5CF6, #4C1D95)' : undefined }}>
                        {(user.name && user.name.length > 0) ? user.name.charAt(0) : 'U'}
                      </div>
                      {isUserOnline(user) && (
                        <span style={{ position: 'absolute', bottom: '0', right: '0', width: '10px', height: '10px', borderRadius: '50%', backgroundColor: '#10B981', border: '2px solid #1A1D24', boxShadow: '0 0 4px #10B981' }} title="Online Now"></span>
                      )}
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <span className="font-medium">{user.name || 'Anonymous User'}</span>
                        {isUserOnline(user) && (
                          <span style={{ fontSize: '10px', color: '#10B981', fontWeight: 'bold', background: 'rgba(16,185,129,0.15)', padding: '1px 6px', borderRadius: '10px' }}>ONLINE</span>
                        )}
                      </div>
                      {user.status === 'suspended' && <span style={{ fontSize: '10px', color: '#EF4444', marginTop: '2px', fontWeight: 'bold' }}>SUSPENDED</span>}
                    </div>
                  </div>
                </td>
                <td className="text-muted">{user.email || 'N/A'}</td>
                <td>
                  <span className={`badge-plan ${user.role === 'admin' ? 'premium' : user.role === 'editor' ? 'free' : ''}`}>
                    {user.role || 'user'}
                  </span>
                </td>
                <td>
                  {(() => {
                    const familyOwner = getFamilyOwner(user.email);
                    if (familyOwner) {
                      return (
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
                          <span className="badge-plan premium">
                            Family Premium
                          </span>
                          <span style={{ fontSize: '11px', color: '#8B5CF6', marginTop: '4px', fontWeight: 'bold' }}>
                            from: {familyOwner.email}
                          </span>
                        </div>
                      );
                    }
                    return (
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
                        <span className={`badge-plan ${(user.subscriptionStatus === 'premium' || user.subscriptionStatus === 'pro') ? 'premium' : 'free'}`}>
                          {user.subscriptionStatus || 'free'}
                        </span>
                        {user.subscriptionStatus === 'premium' && (
                          <div style={{ fontSize: '11px', color: '#10B981', marginTop: '4px' }}>
                            <div>Start: {user.subscriptionStartDate ? new Date(user.subscriptionStartDate).toLocaleDateString() : 'N/A'}</div>
                            <div>Expiry: {user.subscriptionExpiryDate ? new Date(user.subscriptionExpiryDate).toLocaleDateString() : 'N/A'}</div>
                          </div>
                        )}
                        {((user.subscriptionStatus === 'premium' || user.subscriptionStatus === 'pro' || user.role === 'admin') && user.familyMembers && user.familyMembers.length > 0) && (
                          <div style={{ display: 'flex', flexDirection: 'column', marginTop: '4px' }}>
                            <span style={{ fontSize: '11px', color: '#8B5CF6', fontWeight: 'bold' }}>
                              Sharing with:
                            </span>
                            {user.familyMembers.map(email => (
                              <span key={email} style={{ fontSize: '10px', color: '#64748B', marginTop: '2px' }}>• {email}</span>
                            ))}
                          </div>
                        )}
                      </div>
                    );
                  })()}
                </td>
                <td className="text-muted">{user.createdAt ? new Date(user.createdAt.seconds ? user.createdAt.seconds * 1000 : user.createdAt).toLocaleDateString() : 'N/A'}</td>
                <td style={{ textAlign: 'right' }}>
                  <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                    <button className="icon-btn-small" onClick={() => openStatsModal(user)} title="View User Stats">
                      <BarChart2 size={18} color="#14B8A6" />
                    </button>
                    <button className="icon-btn-small" onClick={() => openEditModal(user)} title="Edit Details">
                      <Edit2 size={18} color="#3B82F6" />
                    </button>
                    <button className="icon-btn-small" onClick={() => handlePasswordReset(user.email)} title="Send Password Reset">
                      <Key size={18} color="#F59E0B" />
                    </button>
                    <button className="icon-btn-small" onClick={() => handleDeleteUser(user)} title="Delete User">
                      <Trash2 size={18} color="#EF4444" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Add User Modal */}
      {showAddUserModal && (
        <div className="modal-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="modal-content glass-panel" style={{ width: '500px', padding: '32px', position: 'relative' }}>
            <button onClick={() => setShowAddUserModal(false)} style={{ position: 'absolute', top: '24px', right: '24px', background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}><X size={24} /></button>
            <h2 style={{ marginBottom: '24px' }}>Add New User Manually</h2>
            <form onSubmit={handleAddUser} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Full Name</label>
                <input type="text" required className="input-field" value={addUserForm.name} onChange={e => setAddUserForm({...addUserForm, name: e.target.value})} style={{ width: '100%' }} />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Email Address</label>
                <input type="email" required className="input-field" value={addUserForm.email} onChange={e => setAddUserForm({...addUserForm, email: e.target.value})} style={{ width: '100%' }} />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Password (min 6 characters)</label>
                <input type="password" required minLength="6" className="input-field" value={addUserForm.password} onChange={e => setAddUserForm({...addUserForm, password: e.target.value})} style={{ width: '100%' }} />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Role</label>
                <select className="input-field" value={addUserForm.role} onChange={e => setAddUserForm({...addUserForm, role: e.target.value})} style={{ width: '100%' }}>
                  <option value="user">Customer (User)</option>
                  <option value="editor">Editor (Can manage books)</option>
                  <option value="admin">Admin Superuser (Full Access)</option>
                </select>
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Subscription Status</label>
                <select className="input-field" value={addUserForm.subscriptionStatus} onChange={e => setAddUserForm({...addUserForm, subscriptionStatus: e.target.value})} style={{ width: '100%' }}>
                  <option value="free">Free</option>
                  <option value="premium">Premium</option>
                </select>
              </div>
              
              <button type="submit" disabled={isAddingUser} className="btn-primary" style={{ marginTop: '16px' }}>
                {isAddingUser ? 'Creating Account...' : 'Create User Account'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {showEditModal && selectedUser && (
        <div className="modal-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="modal-content glass-panel" style={{ width: '500px', padding: '32px', position: 'relative' }}>
            <button onClick={() => setShowEditModal(false)} style={{ position: 'absolute', top: '24px', right: '24px', background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}><X size={24} /></button>
            <h2 style={{ marginBottom: '24px' }}>Edit User Details</h2>
            <form onSubmit={saveUserEdits} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Role</label>
                <select className="input-field" value={editForm.role} onChange={e => setEditForm({...editForm, role: e.target.value})} style={{ width: '100%' }}>
                  <option value="user">User (Reader)</option>
                  <option value="editor">Editor (Can manage books)</option>
                  <option value="admin">Admin (Full Access)</option>
                </select>
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Account Status</label>
                <select className="input-field" value={editForm.status} onChange={e => setEditForm({...editForm, status: e.target.value})} style={{ width: '100%' }}>
                  <option value="active">Active</option>
                  <option value="suspended">Suspended</option>
                </select>
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Subscription Status</label>
                <select className="input-field" value={editForm.subscriptionStatus} onChange={e => setEditForm({...editForm, subscriptionStatus: e.target.value})} style={{ width: '100%' }}>
                  <option value="free">Free</option>
                  <option value="premium">Premium</option>
                </select>
              </div>
              {editForm.subscriptionStatus === 'premium' && (
                <>
                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Premium Start Date</label>
                    <input 
                      type="datetime-local" 
                      className="input-field" 
                      value={formatDateTimeLocal(editForm.subscriptionStartDate)} 
                      onChange={e => {
                        const newStart = e.target.value ? new Date(e.target.value).toISOString() : '';
                        let newExpiry = editForm.subscriptionExpiryDate;
                        if (newStart) {
                          const startD = new Date(newStart);
                          const expiryD = new Date(startD.setFullYear(startD.getFullYear() + 1));
                          newExpiry = expiryD.toISOString();
                        }
                        setEditForm({...editForm, subscriptionStartDate: newStart, subscriptionExpiryDate: newExpiry});
                      }} 
                      style={{ width: '100%' }} 
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Premium Expiry Date</label>
                    <input 
                      type="datetime-local" 
                      className="input-field" 
                      value={formatDateTimeLocal(editForm.subscriptionExpiryDate)} 
                      onChange={e => setEditForm({...editForm, subscriptionExpiryDate: e.target.value ? new Date(e.target.value).toISOString() : ''})} 
                      style={{ width: '100%' }} 
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Shared Account (Family Plan)</label>
                    <input type="text" className="input-field" placeholder="Enter comma-separated emails..." value={editForm.familyMembers} onChange={e => setEditForm({...editForm, familyMembers: e.target.value})} style={{ width: '100%' }} />
                    <small style={{ color: '#64748B', display: 'block', marginTop: '4px' }}>Provide emails of users this subscription is shared with.</small>
                  </div>
                </>
              )}
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Phone Number</label>
                <input type="text" className="input-field" value={editForm.phone} onChange={e => setEditForm({...editForm, phone: e.target.value})} style={{ width: '100%' }} />
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#94A3B8' }}>Address/Country</label>
                <input type="text" className="input-field" value={editForm.address} onChange={e => setEditForm({...editForm, address: e.target.value})} style={{ width: '100%' }} />
              </div>
              <button type="submit" className="btn-primary" style={{ marginTop: '16px' }}>Save Changes</button>
            </form>
          </div>
        </div>
      )}

      {/* Stats Sidebar/Modal */}
      {showStatsModal && selectedUser && (
        <div className="modal-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.85)', display: 'flex', justifyContent: 'flex-end', zIndex: 1000 }}>
          <div className="glass-panel" style={{ width: '400px', height: '100%', padding: '32px', overflowY: 'auto', borderLeft: '1px solid #1E293B', borderRadius: 0 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2>User Statistics</h2>
              <button onClick={() => setShowStatsModal(false)} style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}><X size={24} /></button>
            </div>
            
            <div style={{ background: 'rgba(255,255,255,0.05)', padding: '16px', borderRadius: '12px', marginBottom: '24px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div className="avatar" style={{ width: '60px', height: '60px', fontSize: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{(selectedUser.name && selectedUser.name.length > 0) ? selectedUser.name.charAt(0) : 'U'}</div>
                <div>
                  <h3 style={{ margin: 0 }}>{selectedUser.name}</h3>
                  <p style={{ margin: 0, color: '#94A3B8', fontSize: '14px' }}>{selectedUser.email}</p>
                </div>
              </div>
              <div style={{ marginTop: '16px', display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px' }}>
                <p><strong>App Language:</strong> {selectedUser.selectedLanguage?.toUpperCase() || 'EN'}</p>
                <p><strong>Streak:</strong> {selectedUser.streakCount || 0} Days</p>
                <p><strong>Location:</strong> {selectedUser.address || 'Unknown'}</p>
                <p><strong>Phone:</strong> {selectedUser.phone || 'Unknown'}</p>
                <p><strong>Subscription:</strong> {selectedUser.subscriptionStatus === 'premium' ? '👑 Premium' : 'Free'}</p>
                {selectedUser.subscriptionStatus === 'premium' && (
                  <>
                    <p><strong>Premium Since:</strong> {selectedUser.subscriptionStartDate ? new Date(selectedUser.subscriptionStartDate).toLocaleString() : 'N/A'}</p>
                    <p><strong>Premium Expires:</strong> {selectedUser.subscriptionExpiryDate ? new Date(selectedUser.subscriptionExpiryDate).toLocaleString() : 'N/A'}</p>
                  </>
                )}
                <p><strong>Joined:</strong> {selectedUser.createdAt ? new Date(selectedUser.createdAt.seconds ? selectedUser.createdAt.seconds * 1000 : selectedUser.createdAt).toLocaleDateString() : 'N/A'}</p>
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '24px' }}>
              <div style={{ background: 'rgba(20, 184, 166, 0.1)', border: '1px solid rgba(20, 184, 166, 0.2)', padding: '12px', borderRadius: '8px', textAlign: 'center' }}>
                <h4 style={{ margin: '0 0 4px 0', color: '#14B8A6' }}>{selectedUser.completedBooks?.length || 0}</h4>
                <p style={{ margin: 0, fontSize: '12px', color: '#94A3B8' }}>Finished</p>
              </div>
              <div style={{ background: 'rgba(245, 158, 11, 0.1)', border: '1px solid rgba(245, 158, 11, 0.2)', padding: '12px', borderRadius: '8px', textAlign: 'center' }}>
                <h4 style={{ margin: '0 0 4px 0', color: '#F59E0B' }}>{selectedUser.savedBooks?.length || 0}</h4>
                <p style={{ margin: 0, fontSize: '12px', color: '#94A3B8' }}>Saved</p>
              </div>
            </div>

            <h3 style={{ color: '#14B8A6', marginBottom: '12px', fontSize: '16px' }}>Finished Books</h3>
            {selectedUser.completedBooks && selectedUser.completedBooks.length > 0 ? (
              <ul style={{ listStyle: 'none', padding: 0, margin: 0, marginBottom: '24px' }}>
                {selectedUser.completedBooks.map(bid => (
                  <li key={bid} style={{ background: 'rgba(255,255,255,0.05)', padding: '12px', borderRadius: '8px', marginBottom: '8px', fontSize: '14px' }}>
                    ✅ {getBookTitle(bid)}
                  </li>
                ))}
              </ul>
            ) : <p style={{ color: '#94A3B8', fontSize: '14px', marginBottom: '24px' }}>No completed books yet.</p>}

            <h3 style={{ color: '#F59E0B', marginBottom: '12px', fontSize: '16px' }}>Saved Books</h3>
            {selectedUser.savedBooks && selectedUser.savedBooks.length > 0 ? (
              <ul style={{ listStyle: 'none', padding: 0, margin: 0, marginBottom: '24px' }}>
                {selectedUser.savedBooks.map(bid => (
                  <li key={bid} style={{ background: 'rgba(255,255,255,0.05)', padding: '12px', borderRadius: '8px', marginBottom: '8px', fontSize: '14px' }}>
                    🔖 {getBookTitle(bid)}
                  </li>
                ))}
              </ul>
            ) : <p style={{ color: '#94A3B8', fontSize: '14px', marginBottom: '24px' }}>No saved books yet.</p>}

            <h3 style={{ color: '#8B5CF6', marginBottom: '12px', fontSize: '16px' }}>Books in Progress</h3>
            {(() => {
              const inProgressIds = new Set();
              
              if (selectedUser.listeningProgress && typeof selectedUser.listeningProgress === 'object') {
                Object.keys(selectedUser.listeningProgress).forEach(bid => {
                  const clean = bid.replace(/_(en|ku|ar)$/, '');
                  if (!selectedUser.completedBooks?.includes(clean)) {
                    inProgressIds.add(clean);
                  }
                });
              }
              if (selectedUser.readingProgress && typeof selectedUser.readingProgress === 'object') {
                Object.keys(selectedUser.readingProgress).forEach(bid => {
                  const clean = bid.replace(/_(en|ku|ar)$/, '');
                  if (!selectedUser.completedBooks?.includes(clean)) {
                    inProgressIds.add(clean);
                  }
                });
              }
              
              const progressList = Array.from(inProgressIds);
              
              if (progressList.length > 0) {
                return (
                  <ul style={{ listStyle: 'none', padding: 0, margin: 0, marginBottom: '24px' }}>
                    {progressList.map(bid => (
                      <li key={bid} style={{ background: 'rgba(255,255,255,0.05)', padding: '12px', borderRadius: '8px', marginBottom: '8px', fontSize: '14px' }}>
                        📖 {getBookTitle(bid)}
                      </li>
                    ))}
                  </ul>
                );
              }
              return <p style={{ color: '#94A3B8', fontSize: '14px' }}>No active reading or listening in progress.</p>;
            })()}
          </div>
        </div>
      )}
    </div>
  );
};

export default UsersManagement;
