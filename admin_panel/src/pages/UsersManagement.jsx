import { useState, useEffect } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Trash2, CheckCircle, XCircle, X, Edit2, Key, BarChart2, Plus, ArrowUp, ArrowDown, Lock } from 'lucide-react';
import './UsersManagement.css';
import { 
  fetchUsers, 
  subscribeToUsers, 
  fetchBooks, 
  updateUserStatus, 
  sendPasswordResetEmail, 
  createNewUserManually, 
  deleteUser, 
  updateUserPasswordDirectly,
  fetchFamilies,
  fetchFamilyMemberships,
  fetchEntitlements,
  adminUpdateFamilySlotEmail
} from '../services/api';

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
  const [families, setFamilies] = useState([]);
  const [familyMemberships, setFamilyMemberships] = useState([]);
  const [entitlements, setEntitlements] = useState([]);
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
  const [showChangePasswordModal, setShowChangePasswordModal] = useState(false);
  
  const [selectedUser, setSelectedUser] = useState(null);
  const [newDirectPassword, setNewDirectPassword] = useState('');
  const [isUpdatingPassword, setIsUpdatingPassword] = useState(false);

  // Form State for Edit
  const [editForm, setEditForm] = useState({ phone: '', address: '', role: 'user', subscriptionStatus: 'free', status: 'active' });
  const [showCorrectEmailForm, setShowCorrectEmailForm] = useState(false);
  const [correctEmailValue, setCorrectEmailValue] = useState('');
  const [correctEmailReason, setCorrectEmailReason] = useState('');
  const [isCorrectingEmail, setIsCorrectingEmail] = useState(false);
  const [supportFeedback, setSupportFeedback] = useState(null);
  
  // Form State for Add User
  const [addUserForm, setAddUserForm] = useState({ name: '', email: '', password: '', role: 'user', subscriptionStatus: 'free' });
  const [isAddingUser, setIsAddingUser] = useState(false);

  const loadData = async () => {
    try {
      const [usersData, booksData, familiesData, membershipsData, entitlementsData] = await Promise.all([
        fetchUsers(),
        fetchBooks(),
        fetchFamilies().catch(() => []),
        fetchFamilyMemberships().catch(() => []),
        fetchEntitlements().catch(() => []),
      ]);
      setUsers(usersData);
      setBooks(booksData);
      setFamilies(familiesData);
      setFamilyMemberships(membershipsData);
      setEntitlements(entitlementsData);
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

  const getUserFamilyInfo = (user) => {
    if (!user) return { statusText: 'Free', badgeClass: 'free', entitlement: null, family: null, membership: null };
    
    const ent = entitlements.find(e => e.id === user.id);
    const fam = families.find(f => f.id === user.id);
    const mem = familyMemberships.find(m => m.id === user.id);

    // Check if recipient of a pending invitation by email
    const pendingFamInvite = !mem && families.find(f => 
      f.invitation?.recipientEmail && 
      user.email && 
      f.invitation.recipientEmail.toLowerCase() === user.email.toLowerCase()
    );

    // 1. Family Shared (Recipient)
    if (ent?.source === 'family' && ent?.status === 'active') {
      const owner = users.find(u => u.id === (ent.ownerUid || mem?.ownerUid));
      return {
        statusText: 'Premium — Family Shared',
        badgeClass: 'shared',
        entitlement: ent,
        family: null,
        membership: mem,
        ownerEmail: owner?.email || ent.ownerUid || 'Family Owner',
        ownerUid: ent.ownerUid || mem?.ownerUid,
      };
    }
    if (mem?.state === 'active') {
      const owner = users.find(u => u.id === mem.ownerUid);
      return {
        statusText: 'Premium — Family Shared',
        badgeClass: 'shared',
        entitlement: ent,
        family: null,
        membership: mem,
        ownerEmail: owner?.email || mem.ownerUid || 'Family Owner',
        ownerUid: mem.ownerUid,
      };
    }
    if (mem?.state === 'pending' || pendingFamInvite) {
      const invFam = pendingFamInvite || families.find(f => f.id === mem?.ownerUid);
      const owner = users.find(u => u.id === (mem?.ownerUid || invFam?.id));
      return {
        statusText: 'Family Invitation Pending',
        badgeClass: 'warning',
        entitlement: ent,
        family: null,
        membership: mem,
        ownerEmail: owner?.email || 'Family Owner',
        ownerUid: mem?.ownerUid || invFam?.id,
      };
    }

    // 2. Family Owner
    if (fam) {
      const hasActive = fam.memberUid || fam.memberEmail;
      const hasInvite = fam.invitation && fam.invitation.recipientEmail;
      const isOwnerPremium = ent?.status === 'active' || user.subscriptionStatus === 'premium' || user.subscriptionStatus === 'pro';

      if (hasActive) {
        return {
          statusText: 'Premium — Family Owner',
          badgeClass: 'premium',
          entitlement: ent,
          family: fam,
          membership: null,
          memberEmail: fam.memberEmail || fam.lockedRecipientEmail,
          memberState: 'active',
        };
      }
      if (hasInvite) {
        return {
          statusText: 'Premium — Family Owner',
          badgeClass: 'premium',
          entitlement: ent,
          family: fam,
          membership: null,
          memberEmail: fam.invitation.recipientEmail,
          memberState: 'pending',
        };
      }
      if (fam.lockedRecipientEmail) {
        return {
          statusText: 'Premium — Family Owner',
          badgeClass: 'premium',
          entitlement: ent,
          family: fam,
          membership: null,
          memberEmail: fam.lockedRecipientEmail,
          memberState: 'vacated',
        };
      }
      if (isOwnerPremium) {
        return {
          statusText: 'Premium — Family Owner',
          badgeClass: 'premium',
          entitlement: ent,
          family: fam,
          membership: null,
          memberEmail: null,
          memberState: 'empty',
        };
      }
    }

    // 3. Regular Premium
    const isPremium = ent?.status === 'active' || user.subscriptionStatus === 'premium' || user.subscriptionStatus === 'pro';
    if (isPremium) {
      return {
        statusText: 'Premium',
        badgeClass: 'premium',
        entitlement: ent,
        family: null,
        membership: null,
      };
    }

    // 4. Free
    return {
      statusText: 'Free',
      badgeClass: 'free',
      entitlement: ent,
      family: null,
      membership: null,
    };
  };

  const openEditModal = (user) => {
    setSelectedUser(user);
    setShowCorrectEmailForm(false);
    setCorrectEmailValue('');
    setCorrectEmailReason('');
    setSupportFeedback(null);
    setEditForm({
      phone: user.phone || '',
      address: user.address || '',
      role: user.role || 'user',
      subscriptionStatus: user.subscriptionStatus || 'free',
      status: user.status || 'active',
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
      // Family relationships are callable/backend-owned.
      delete payload.familyMembers;
      
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
      aVal = getUserFamilyInfo(a).statusText.toLowerCase();
      bVal = getUserFamilyInfo(b).statusText.toLowerCase();
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
                    const info = getUserFamilyInfo(user);
                    return (
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
                        <span className={`badge-plan ${info.badgeClass}`}>
                          {info.statusText}
                        </span>
                        {info.memberEmail && (
                          <span style={{ fontSize: '11px', color: '#8B5CF6', marginTop: '4px', fontWeight: 'bold' }}>
                            {info.memberState === 'pending' ? 'Invited: ' : 'Member: '} {info.memberEmail}
                          </span>
                        )}
                        {info.ownerEmail && (
                          <span style={{ fontSize: '11px', color: '#8B5CF6', marginTop: '4px', fontWeight: 'bold' }}>
                            from: {info.ownerEmail}
                          </span>
                        )}
                        {(user.subscriptionExpiryDate || info.entitlement?.expiresAt) && (
                          <span style={{ fontSize: '10px', color: '#64748B', marginTop: '2px' }}>
                            Exp: {new Date(info.entitlement?.expiresAt?.seconds ? info.entitlement.expiresAt.seconds * 1000 : (info.entitlement?.expiresAt || user.subscriptionExpiryDate)).toLocaleDateString()}
                          </span>
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
                    <button className="icon-btn-small" onClick={() => { setSelectedUser(user); setNewDirectPassword(''); setShowChangePasswordModal(true); }} title="Set New Password Directly">
                      <Lock size={18} color="#8B5CF6" />
                    </button>
                    <button className="icon-btn-small" onClick={() => handlePasswordReset(user.email)} title="Send Password Reset Email">
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
          <div className="modal-content glass-panel" style={{ width: '500px', maxHeight: '90vh', overflowY: 'auto', padding: '32px', position: 'relative' }}>
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
                </>
              )}

              {/* Family & Entitlement Information (Read-Only) */}
              {(() => {
                const info = getUserFamilyInfo(selectedUser);
                const expiryDate = info.entitlement?.expiresAt 
                  ? (info.entitlement.expiresAt.seconds ? new Date(info.entitlement.expiresAt.seconds * 1000).toLocaleString() : new Date(info.entitlement.expiresAt).toLocaleString())
                  : (selectedUser.subscriptionExpiryDate ? new Date(selectedUser.subscriptionExpiryDate).toLocaleString() : 'None / Indefinite');
                const source = info.entitlement?.source || (selectedUser.subscriptionStatus === 'premium' ? 'manual/profile' : 'none');

                return (
                  <div style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '10px', padding: '14px', marginTop: '4px', marginBottom: '4px' }}>
                    <div style={{ fontSize: '12px', fontWeight: 'bold', color: '#94A3B8', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '8px' }}>
                      Family & Entitlement Status (Read-Only)
                    </div>
                    <div style={{ fontSize: '13px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <div><strong>Current Status:</strong> <span style={{ color: info.badgeClass === 'premium' ? '#F59E0B' : '#94A3B8' }}>{info.statusText}</span></div>
                      <div><strong>Entitlement Source:</strong> <code style={{ background: 'rgba(0,0,0,0.3)', padding: '2px 6px', borderRadius: '4px', marginLeft: '6px' }}>{source}</code></div>
                      <div><strong>Expiry Date:</strong> {expiryDate}</div>
                      
                      {/* Family Owner Details */}
                      {info.family && (
                        <div style={{ marginTop: '6px', borderTop: '1px solid rgba(255,255,255,0.06)', paddingTop: '8px' }}>
                          <div><strong>Assigned Family Member:</strong> {info.memberEmail || 'None assigned yet'}</div>
                          <div><strong>Slot Status:</strong> {info.memberState === 'active' ? 'Active Member' : info.memberState === 'pending' ? 'Invitation Pending' : info.memberState === 'vacated' ? 'Vacated (Locked Slot)' : 'Empty Slot'}</div>
                          
                          {/* Admin support correction button & feedback */}
                          <div style={{ marginTop: '10px' }}>
                            {supportFeedback && (
                              <div style={{
                                padding: '8px 12px',
                                borderRadius: '6px',
                                marginBottom: '10px',
                                fontSize: '12px',
                                background: supportFeedback.type === 'error' ? 'rgba(239,68,68,0.15)' : 'rgba(16,185,129,0.15)',
                                color: supportFeedback.type === 'error' ? '#FCA5A5' : '#6EE7B7',
                                border: `1px solid ${supportFeedback.type === 'error' ? 'rgba(239,68,68,0.3)' : 'rgba(16,185,129,0.3)'}`
                              }}>
                                {supportFeedback.message}
                              </div>
                            )}

                            {!showCorrectEmailForm ? (
                              <button
                                type="button"
                                className="btn-secondary"
                                style={{ fontSize: '12px', padding: '6px 12px', background: 'rgba(139,92,246,0.15)', color: '#A78BFA', border: '1px solid rgba(139,92,246,0.3)', borderRadius: '6px', cursor: 'pointer' }}
                                onClick={() => {
                                  setShowCorrectEmailForm(true);
                                  setCorrectEmailValue(info.memberEmail || '');
                                  setCorrectEmailReason('');
                                  setSupportFeedback(null);
                                }}
                              >
                                Support: Correct Member Email
                              </button>
                            ) : (
                              <div style={{ background: 'rgba(0,0,0,0.25)', border: '1px solid rgba(139,92,246,0.3)', padding: '12px', borderRadius: '8px', marginTop: '8px' }}>
                                <label style={{ display: 'block', fontSize: '11px', color: '#CBD5E1', marginBottom: '4px' }}>New Recipient Email</label>
                                <input
                                  type="email"
                                  className="input-field"
                                  style={{ width: '100%', fontSize: '12px', marginBottom: '8px' }}
                                  value={correctEmailValue}
                                  onChange={e => setCorrectEmailValue(e.target.value)}
                                  placeholder="e.g. member@gmail.com"
                                  disabled={isCorrectingEmail}
                                />
                                <label style={{ display: 'block', fontSize: '11px', color: '#CBD5E1', marginBottom: '4px' }}>Reason for Support Override</label>
                                <input
                                  type="text"
                                  className="input-field"
                                  style={{ width: '100%', fontSize: '12px', marginBottom: '10px' }}
                                  value={correctEmailReason}
                                  onChange={e => setCorrectEmailReason(e.target.value)}
                                  placeholder="e.g. Typo in email address"
                                  disabled={isCorrectingEmail}
                                />
                                <div style={{ display: 'flex', gap: '8px' }}>
                                  <button
                                    type="button"
                                    className="btn-primary"
                                    style={{ fontSize: '12px', padding: '5px 12px' }}
                                    disabled={isCorrectingEmail}
                                    onClick={async () => {
                                      const normEmail = correctEmailValue.trim().toLowerCase();
                                      const normReason = correctEmailReason.trim();

                                      if (!normEmail || !/^\S+@\S+\.\S+$/.test(normEmail)) {
                                        setSupportFeedback({ type: 'error', message: 'Please enter a valid email address.' });
                                        return;
                                      }
                                      if (!normReason) {
                                        setSupportFeedback({ type: 'error', message: 'Please provide a non-empty support reason.' });
                                        return;
                                      }

                                      setIsCorrectingEmail(true);
                                      setSupportFeedback(null);

                                      try {
                                        // 1. Await callable
                                        const res = await adminUpdateFamilySlotEmail(selectedUser.id, normEmail, normReason);
                                        if (!res || !res.success) {
                                          throw new Error(res?.message || 'Server did not confirm success.');
                                        }

                                        // 2. Refetch canonical data
                                        const [refetchedFamilies, refetchedMemberships, refetchedEntitlements, refetchedUsers] = await Promise.all([
                                          fetchFamilies(),
                                          fetchFamilyMemberships(),
                                          fetchEntitlements(),
                                          fetchUsers(),
                                        ]);

                                        // 3. Verify canonical state proves the change
                                        const updatedFam = refetchedFamilies.find(f => f.id === selectedUser.id);
                                        if (!updatedFam) {
                                          throw new Error('State verification failed: Owner family record not found.');
                                        }
                                        if ((updatedFam.lockedRecipientEmail || '').toLowerCase() !== normEmail) {
                                          throw new Error(`State verification failed: Locked recipient is "${updatedFam.lockedRecipientEmail}", expected "${normEmail}".`);
                                        }
                                        if (!updatedFam.invitation || (updatedFam.invitation.recipientEmail || '').toLowerCase() !== normEmail) {
                                          throw new Error('State verification failed: Pending invitation for new email was not created.');
                                        }
                                        if (updatedFam.memberUid || updatedFam.memberEmail) {
                                          throw new Error('State verification failed: Old member is still assigned on family record.');
                                        }

                                        // If old member had a UID, verify revocation
                                        if (res.oldUid) {
                                          const oldEnt = refetchedEntitlements.find(e => e.id === res.oldUid);
                                          if (oldEnt && oldEnt.source === 'family' && oldEnt.status === 'active') {
                                            throw new Error('State verification failed: Old member entitlement is still active.');
                                          }
                                          const oldMem = refetchedMemberships.find(m => m.id === res.oldUid);
                                          if (oldMem && oldMem.state === 'active') {
                                            throw new Error('State verification failed: Old member family membership is still active.');
                                          }
                                        }

                                        // 4. Update table and modal state
                                        setFamilies(refetchedFamilies);
                                        setFamilyMemberships(refetchedMemberships);
                                        setEntitlements(refetchedEntitlements);
                                        setUsers(refetchedUsers);

                                        const updatedSelected = refetchedUsers.find(u => u.id === selectedUser.id) || selectedUser;
                                        setSelectedUser(updatedSelected);

                                        setSupportFeedback({
                                          type: 'success',
                                          message: `Family member email successfully updated to ${normEmail}. Old member revoked, slot locked, and new invitation pending.`
                                        });
                                        setShowCorrectEmailForm(false);
                                      } catch (err) {
                                        console.error('Support correction error:', err);
                                        setSupportFeedback({
                                          type: 'error',
                                          message: err.message || 'Failed to update email: ' + String(err)
                                        });
                                        // Retain form values!
                                      } finally {
                                        setIsCorrectingEmail(false);
                                      }
                                    }}
                                  >
                                    {isCorrectingEmail ? 'Saving...' : 'Apply Correction'}
                                  </button>
                                  <button
                                    type="button"
                                    className="btn-secondary"
                                    style={{ fontSize: '12px', padding: '5px 12px' }}
                                    onClick={() => {
                                      setShowCorrectEmailForm(false);
                                      setSupportFeedback(null);
                                    }}
                                  >
                                    Cancel
                                  </button>
                                </div>
                              </div>
                            )}
                          </div>
                        </div>
                      )}

                      {/* Family Recipient Details */}
                      {info.ownerEmail && (
                        <div style={{ marginTop: '6px', borderTop: '1px solid rgba(255,255,255,0.06)', paddingTop: '8px' }}>
                          <div><strong>Linked Family Owner:</strong> {info.ownerEmail}</div>
                          <div><strong>Membership State:</strong> {info.membership?.state || (info.entitlement?.status === 'active' ? 'active' : 'pending')}</div>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })()}

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

      {/* Change Password Modal */}
      {showChangePasswordModal && selectedUser && (
        <div className="modal-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="modal-content glass-panel" style={{ width: '440px', padding: '32px', position: 'relative' }}>
            <button onClick={() => setShowChangePasswordModal(false)} style={{ position: 'absolute', top: '24px', right: '24px', background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}><X size={24} /></button>
            <h2 style={{ marginBottom: '12px', fontSize: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Lock size={22} color="#8B5CF6" /> Set New Password
            </h2>
            <p style={{ color: '#94A3B8', fontSize: '13px', marginBottom: '20px' }}>
              Directly update the login password for <strong>{selectedUser.name || selectedUser.email}</strong>.
            </p>
            <form onSubmit={async (e) => {
              e.preventDefault();
              if (!newDirectPassword || newDirectPassword.length < 6) {
                alert("Password must be at least 6 characters long.");
                return;
              }
              setIsUpdatingPassword(true);
              try {
                await updateUserPasswordDirectly(selectedUser.id, selectedUser.email, newDirectPassword);
                alert(`Password updated successfully for ${selectedUser.email}!`);
                setShowChangePasswordModal(false);
              } catch (err) {
                alert("Error updating password: " + err.message);
              } finally {
                setIsUpdatingPassword(false);
              }
            }} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', color: '#CBD5E1', fontSize: '13px', fontWeight: '600' }}>New Password</label>
                <input 
                  type="password" 
                  required 
                  minLength={6} 
                  placeholder="Enter new password (min 6 chars)" 
                  className="input-field" 
                  value={newDirectPassword} 
                  onChange={e => setNewDirectPassword(e.target.value)} 
                  style={{ width: '100%', padding: '12px', borderRadius: '8px', background: 'rgba(15,23,42,0.8)', border: '1px solid rgba(255,255,255,0.15)', color: '#fff' }} 
                />
              </div>
              <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '12px' }}>
                <button type="button" className="btn-secondary" onClick={() => setShowChangePasswordModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" disabled={isUpdatingPassword}>
                  {isUpdatingPassword ? "Updating..." : "Save New Password"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default UsersManagement;
