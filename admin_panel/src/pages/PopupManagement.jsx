import { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2, Copy, Play, Pause, Bell, ShieldAlert, Eye, Calendar, Globe, Info, AlertTriangle, Clock, X, Check, Save, Megaphone, Send } from 'lucide-react';
import { fetchPopups, addPopup, updatePopup, deletePopup, fetchAuditLogs, writeAuditLog, fetchGlobalSettings, saveGlobalSettings, fetchBooks } from '../services/api';
import './PopupManagement.css';

const TEMPLATES = {
  app_update: {
    title: {
      en: "New Version Available!",
      ar: "نسخة جديدة متوفرة!",
      ku: "وەشانی نوێ بەردەستە!"
    },
    body: {
      en: "A new version of Partwk is available now. Please update to enjoy the latest book summaries, audio narration, and micro-learning features.",
      ar: "نسخة جديدة من تطبيق Partwk متوفرة الآن. يرجى التحديث للاستمتاع بأحدث ملخصات الكتب، السرد الصوتي، وميزات التعلم المصغر.",
      ku: "وەشانێکی نوێی ئەپی Partwk ئێستا بەردەستە. تکایە ئەپدێتی بکەرەوە بۆ چێژوەرگرتن لە دوایین کورتکراوەی پەرتووکەکان، خوێندنەوەی دەنگی و تایبەتمەندییەکانی فێربوون."
    },
    type: "update",
    priority: "important",
    frequency: "until_dismissed",
    actionUrl: "https://apps.apple.com/app/partwk",
    actionText: {
      en: "Update Now",
      ar: "تحديث الآن",
      ku: "ئێستا ئەپدێت بکە"
    }
  },
  maintenance: {
    title: {
      en: "Scheduled Maintenance",
      ar: "صيانة مجدولة للمنصة",
      ku: "چاکسازی پلان بۆ داڕێژراو"
    },
    body: {
      en: "We will undergo a scheduled system maintenance on Sunday at 02:00 AM UTC. Some features might be temporarily unavailable.",
      ar: "سنقوم بإجراء صيانة مجدولة للنظام يوم الأحد الساعة 02:00 صباحاً بالتوقيت العالمي. قد تكون بعض الميزات غير متوفرة مؤقتاً.",
      ku: "ڕۆژی یەکشەممە کاتژمێر ٠٢:٠٠ی بەیانی بەکاتی UTC چاکسازی پلان بۆ داڕێژراوی سیستەم ئەنجام دەدەین. ڕەنگە هەندێک تایبەتمەندی بە شێوەیەکی کاتی بەردەست نەبن."
    },
    type: "maintenance",
    priority: "urgent",
    frequency: "every_open",
    actionUrl: "",
    actionText: {
      en: "Got It",
      ar: "حسناً",
      ku: "تێگەیشتم"
    }
  },
  premium_promo: {
    title: {
      en: "Unlock Partwk Premium!",
      ar: "احصل على العضوية المميزة!",
      ku: "تایبەتمەندی پریمیۆم چالاک بکە!"
    },
    body: {
      en: "Get unlimited access to all curated book summaries, native audio narration, quizzes, and personal learning paths with 30% off today.",
      ar: "احصل على وصول غير محدود لجميع ملخصات الكتب المنسقة، السرد الصوتي الأصلي، الاختبارات ومسارات التعلم الشخصية بخصم 30٪ اليوم.",
      ku: "دەستگەیشتنی بێسنوور بەدەستبهێنە بۆ هەموو کورتکراوەی پەرتووکەکان، خوێندنەوەی دەنگی ڕەسەن، کویزەکان و مسارەکانی فێربوونی کەسی بە داشکاندنی ٣٠٪ بۆ ئەمڕۆ."
    },
    type: "promotion",
    priority: "normal",
    frequency: "once",
    actionUrl: "partwk://paywall",
    actionText: {
      en: "Get 30% Off",
      ar: "احصل على خصم 30٪",
      ku: "داشکاندنی ٣٠٪ بەدەستبهێنە"
    }
  },
  new_book: {
    title: {
      en: "New Summary: 4000 Weeks",
      ar: "ملخص جديد: 4000 أسبوع",
      ku: "کورتکراوەی نوێ: ٤٠٠٠ هەفتە"
    },
    body: {
      en: "Discover Oliver Burkeman's guide to time management, embracing your limits, and making the most of your 4,000 weeks on earth.",
      ar: "اكتشف دليل أوليفر بيركمان لإدارة الوقت، وتقبل حدودك، وتحقيق أقصى استفادة من 4000 أسبوع على الأرض.",
      ku: "ڕێبەری ئۆلیڤەر بێرکمان بۆ بەڕێوەبردنی کات بدۆزەرەوە، داننان بە سنوورەکانتدا، و بەدەستهێنانی زۆرترین سوود لە ٤٠٠٠ هەفتەی سەر زەوی."
    },
    type: "new_book",
    priority: "normal",
    frequency: "once",
    actionUrl: "partwk://book/4000_weeks",
    actionText: {
      en: "Read / Listen Now",
      ar: "اقرأ / استمع الآن",
      ku: "ئێستا بخوێنەوە / گوێ بگرە"
    }
  }
};

const PopupManagement = () => {
  const [popups, setPopups] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [disableAllPopups, setDisableAllPopups] = useState(false);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('popups'); // 'popups' or 'logs'
  
  // Deploy target settings modal
  const [showDeployModal, setShowDeployModal] = useState(false);
  const [deployingPopup, setDeployingPopup] = useState(null);
  const [deployAudienceType, setDeployAudienceType] = useState('all');
  const [deployEmails, setDeployEmails] = useState('');
  
  // Recent books list
  const [recentBooks, setRecentBooks] = useState([]);

  
  // Modals & Creation Drawer
  const [showFormModal, setShowFormModal] = useState(false);
  const [selectedPopup, setSelectedPopup] = useState(null);
  
  // Form State
  const initialFormState = {
    title: { en: '', ar: '', ku: '' },
    body: { en: '', ar: '', ku: '' },
    type: 'info',
    status: 'draft',
    priority: 'normal',
    frequency: 'once',
    imageUrl: '',
    actionUrl: '',
    actionText: { en: 'Open Link', ar: 'فتح الرابط', ku: 'کردنەوەی بەستەر' },
    scheduling: { startDate: '', endDate: '' },
    targeting: {
      languages: ['en', 'ar', 'ku'],
      userTypes: [], // empty means all
      countries: [],
      platforms: [],
      appVersions: [],
      emails: [],
      userIds: []
    }
  };
  const [form, setForm] = useState(initialFormState);
  
  // Preview Language Selection
  const [previewLang, setPreviewLang] = useState('en');

  // Load Data
  const loadData = async () => {
    try {
      setLoading(true);
      const [popupsData, logsData, settingsData, booksData] = await Promise.all([
        fetchPopups(),
        fetchAuditLogs(),
        fetchGlobalSettings(),
        fetchBooks()
      ]);
      // Safe timestamp resolver for strings, Date objects, and Firestore Timestamps
      const getTimestamp = (val) => {
        if (!val) return 0;
        if (val.seconds !== undefined) return val.seconds * 1000;
        if (val.toDate && typeof val.toDate === 'function') return val.toDate().getTime();
        const parsed = new Date(val).getTime();
        return isNaN(parsed) ? 0 : parsed;
      };

      setPopups(popupsData);
      // Sort logs by timestamp descending
      setAuditLogs(logsData.sort((a, b) => getTimestamp(b.timestamp) - getTimestamp(a.timestamp)));
      if (settingsData && settingsData.disableAllPopups !== undefined) {
        setDisableAllPopups(settingsData.disableAllPopups);
      }
      // Sort books by createdAt descending, take first 5
      const sortedBooks = booksData
        .sort((a, b) => getTimestamp(b.createdAt) - getTimestamp(a.createdAt))
        .slice(0, 5);
      setRecentBooks(sortedBooks);
    } catch (e) {
      console.error("Error loading popup management data:", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Emergency Toggle
  const handleEmergencyToggle = async (checked) => {
    try {
      await saveGlobalSettings({ disableAllPopups: checked });
      setDisableAllPopups(checked);
      await writeAuditLog(
        'emergency_toggle', 
        `Emergency switch set to ${checked ? 'DISABLED (All popups blocked)' : 'ENABLED (Standard popups active)'}`
      );
      alert(`Emergency master switch updated successfully! All popups are now ${checked ? 'suppressed' : 'active according to rules'}.`);
      loadData();
    } catch (e) {
      alert("Failed to update emergency switch: " + e.message);
    }
  };

  // Open creation modal
  const handleOpenCreate = () => {
    setSelectedPopup(null);
    setForm(initialFormState);
    setShowFormModal(true);
  };

  // Open edit modal
  const handleOpenEdit = (popup) => {
    setSelectedPopup(popup);
    setForm({
      title: { ...initialFormState.title, ...popup.title },
      body: { ...initialFormState.body, ...popup.body },
      type: popup.type || 'info',
      status: popup.status || 'draft',
      priority: popup.priority || 'normal',
      frequency: popup.frequency || 'once',
      imageUrl: popup.imageUrl || '',
      actionUrl: popup.actionUrl || '',
      actionText: { ...initialFormState.actionText, ...popup.actionText },
      scheduling: {
        startDate: popup.scheduling?.startDate || '',
        endDate: popup.scheduling?.endDate || ''
      },
      targeting: {
        languages: popup.targeting?.languages || ['en', 'ar', 'ku'],
        userTypes: popup.targeting?.userTypes || [],
        countries: popup.targeting?.countries || [],
        platforms: popup.targeting?.platforms || [],
        appVersions: popup.targeting?.appVersions || [],
        emails: popup.targeting?.emails || [],
        userIds: popup.targeting?.userIds || []
      }
    });
    setShowFormModal(true);
  };

  // Template autofill
  const handleApplyTemplate = (templateKey) => {
    const template = TEMPLATES[templateKey];
    if (!template) return;
    
    setForm(prev => ({
      ...prev,
      title: { ...template.title },
      body: { ...template.body },
      type: template.type,
      priority: template.priority,
      frequency: template.frequency,
      actionUrl: template.actionUrl,
      actionText: { ...template.actionText }
    }));
  };

  // Book template autofill
  const handleApplyBookTemplate = (bookId) => {
    const book = recentBooks.find(b => b.id === bookId);
    if (!book) return;

    let coverUrl = '';
    if (typeof book.coverImageUrl === 'string') {
      coverUrl = book.coverImageUrl;
    } else if (book.coverImageUrl && typeof book.coverImageUrl === 'object') {
      coverUrl = book.coverImageUrl.en || book.coverImageUrl.ku || book.coverImageUrl.ar || '';
    }

    setForm(prev => ({
      ...prev,
      title: {
        en: `New Book: ${book.title?.en || ''}`,
        ku: `پەرتووکی نوێ: ${book.title?.ku || book.title?.en || ''}`,
        ar: `كتاب جديد: ${book.title?.ar || book.title?.en || ''}`
      },
      body: {
        en: `Check out the new curated summary for "${book.title?.en || ''}" by ${book.author?.en || 'Unknown'} now!`,
        ku: `کورتکراوەی نوێی "${book.title?.ku || book.title?.en || ''}" نووسینی ${book.author?.ku || book.author?.en || 'Unknown'} بخوێنەرەوە یان گوێی لێ بگرە!`,
        ar: `اقرأ أو استمع إلى الملخص المنسق لكتاب "${book.title?.ar || book.title?.en || ''}" بقلم ${book.author?.ar || book.author?.en || 'Unknown'} الآن!`
      },
      type: "new_book",
      priority: "normal",
      frequency: "once",
      imageUrl: coverUrl,
      actionUrl: `partwk://book/${book.id}`,
      actionText: {
        en: "Read / Listen Now",
        ar: "اقرأ / استمع الآن",
        ku: "ئێستا بخوێنەوە / گوێ بگرە"
      }
    }));
  };

  // Form submit
  const handleSaveForm = async (e) => {
    e.preventDefault();
    try {
      if (selectedPopup) {
        // Edit Mode
        await updatePopup(selectedPopup.id, form);
        await writeAuditLog('edit', `Updated popup ID: ${selectedPopup.id} ("${form.title.en || 'Untitled'}")`);
        alert("Popup updated successfully!");
      } else {
        // Create Mode
        const newId = await addPopup(form);
        await writeAuditLog('create', `Created new popup ID: ${newId} ("${form.title.en || 'Untitled'}")`);
        alert("Popup created successfully!");
      }
      setShowFormModal(false);
      loadData();
    } catch (error) {
      alert("Failed to save popup: " + error.message);
    }
  };

  // Duplicate Popup
  const handleDuplicate = async (popup) => {
    try {
      const duplicatedData = {
        ...popup,
        title: { ...popup.title, en: `${popup.title.en || ''} (Copy)` },
        status: 'draft', // defaults to draft
        analytics: { seen: 0, clicked: 0, dismissed: 0, conversion: 0 }
      };
      delete duplicatedData.id; // remove old ID so endpoint regenerates it
      const newId = await addPopup(duplicatedData);
      await writeAuditLog('duplicate', `Cloned popup ID: ${popup.id} into duplicate ID: ${newId}`);
      alert("Popup duplicated successfully!");
      loadData();
    } catch (e) {
      alert("Duplicate failed: " + e.message);
    }
  };

  // Pause / Resume Toggle
  const handleToggleStatus = async (popup) => {
    try {
      const newStatus = popup.status === 'active' ? 'paused' : 'active';
      await updatePopup(popup.id, { status: newStatus });
      await writeAuditLog(newStatus === 'active' ? 'publish' : 'pause', `${newStatus === 'active' ? 'Activated' : 'Paused'} popup ID: ${popup.id}`);
      loadData();
    } catch (e) {
      alert("Status change failed: " + e.message);
    }
  };

  // Delete Popup
  const handleDelete = async (popup) => {
    if (window.confirm(`Are you sure you want to delete this popup Campaign: "${popup.title.en || 'Untitled'}"?`)) {
      try {
        await deletePopup(popup.id);
        await writeAuditLog('delete', `Deleted popup ID: ${popup.id} ("${popup.title.en || 'Untitled'}")`);
        alert("Popup deleted successfully!");
        loadData();
      } catch (e) {
        alert("Deletion failed: " + e.message);
      }
    }
  };

  // Deploy campaign targeting specific groups
  const handleDeployCampaign = async (e) => {
    e.preventDefault();
    if (!deployingPopup) return;

    try {
      let finalUserTypes = [];
      let finalEmails = [];

      if (deployAudienceType === 'premium') {
        finalUserTypes = ['premium'];
      } else if (deployAudienceType === 'free') {
        finalUserTypes = ['free'];
      } else if (deployAudienceType === 'unregistered') {
        finalUserTypes = ['unregistered'];
      } else if (deployAudienceType === 'emails') {
        if (!deployEmails) {
          alert("Please enter at least one target email.");
          return;
        }
        finalEmails = deployEmails.split(',').map(s => s.trim().toLowerCase()).filter(s => s.length > 0);
      }

      const updatedTargeting = {
        ...deployingPopup.targeting,
        userTypes: finalUserTypes,
        emails: finalEmails
      };

      await updatePopup(deployingPopup.id, {
        status: 'active',
        targeting: updatedTargeting
      });

      await writeAuditLog('publish', `Deployed campaign ID: ${deployingPopup.id} ("${deployingPopup.title?.en || 'Untitled'}") to audience: ${deployAudienceType}`);
      alert(`Campaign deployed successfully to ${deployAudienceType.toUpperCase()} target!`);
      setShowDeployModal(false);
      loadData();
    } catch (error) {
      alert("Failed to deploy campaign: " + error.message);
    }
  };

  // Test Trigger targeting admin
  const handleTestPopup = async (popup, testEmail) => {
    if (!testEmail) {
      alert("Please enter a valid test user email.");
      return;
    }
    try {
      // Just merge testEmail into popup emails targeting
      const currentEmails = popup.targeting?.emails || [];
      if (!currentEmails.includes(testEmail)) {
        const updatedTarget = {
          ...popup.targeting,
          emails: [...currentEmails, testEmail]
        };
        await updatePopup(popup.id, {
          status: 'active', // force active for test delivery
          targeting: updatedTarget
        });
        await writeAuditLog('test_trigger', `Sent test popup ID: ${popup.id} to test email: ${testEmail}`);
        alert(`Test popup deployed! If '${testEmail}' logs in on the mobile app, they will see it immediately.`);
        loadData();
      } else {
        alert(`Target email '${testEmail}' is already configured inside targeting rules for this popup.`);
      }
    } catch (e) {
      alert("Failed to trigger test: " + e.message);
    }
  };

  // Helpers for text colors and badges
  const getPriorityBadgeClass = (priority) => {
    switch (priority) {
      case 'urgent': return 'badge-plan urgent-badge';
      case 'important': return 'badge-plan important-badge';
      default: return 'badge-plan normal-badge';
    }
  };

  const getTypeBadgeClass = (type) => {
    return `popup-type-badge ${type}-type`;
  };

  return (
    <div className="dashboard-page popup-management-page">
      
      {/* Header controls & emergency master switch */}
      <div className="page-header" style={{ marginBottom: '24px' }}>
        <h1 className="page-title">Popup & Broadcast Messaging</h1>
        <div className="header-actions" style={{ display: 'flex', gap: '20px', alignItems: 'center' }}>
          
          {/* Emergency Kill-Switch UI */}
          <div className="emergency-container glass-panel" style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '8px 16px', borderRadius: '12px' }}>
            <ShieldAlert size={20} className={disableAllPopups ? "text-red animate-pulse" : "text-muted"} />
            <div className="emergency-label-group" style={{ display: 'flex', flexDirection: 'column' }}>
              <span className="emergency-title" style={{ fontSize: '13px', fontWeight: 'bold', color: '#fff' }}>Emergency Freeze Mode</span>
              <span className="emergency-desc" style={{ fontSize: '11px', color: '#94A3B8' }}>Block all app overlays instantly</span>
            </div>
            <label className="switch" style={{ position: 'relative', display: 'inline-block', width: '44px', height: '24px', marginLeft: '8px' }}>
              <input 
                type="checkbox" 
                checked={disableAllPopups} 
                onChange={(e) => handleEmergencyToggle(e.target.checked)} 
                style={{ opacity: 0, width: 0, height: 0 }}
              />
              <span className="slider round" style={{ position: 'absolute', cursor: 'pointer', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: disableAllPopups ? '#EF4444' : '#1E293B', transition: '0.4s', borderRadius: '34px' }}></span>
            </label>
          </div>

          <button className="btn-primary" onClick={handleOpenCreate}>
            <Plus size={18} />
            <span>Create Campaign</span>
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="sub-tabs" style={{ display: 'flex', gap: '12px', marginBottom: '24px', borderBottom: '1px solid var(--color-border)', paddingBottom: '12px' }}>
        <button 
          className={`sub-tab ${activeTab === 'popups' ? 'active' : ''}`} 
          onClick={() => setActiveTab('popups')}
          style={{ padding: '8px 16px', background: activeTab === 'popups' ? 'rgba(255,255,255,0.1)' : 'transparent', border: 'none', borderRadius: '8px', color: activeTab === 'popups' ? '#fff' : '#94A3B8', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 'bold' }}
        >
          <Bell size={16} />
          <span>Active Campaigns ({popups.length})</span>
        </button>
        <button 
          className={`sub-tab ${activeTab === 'logs' ? 'active' : ''}`} 
          onClick={() => setActiveTab('logs')}
          style={{ padding: '8px 16px', background: activeTab === 'logs' ? 'rgba(255,255,255,0.1)' : 'transparent', border: 'none', borderRadius: '8px', color: activeTab === 'logs' ? '#fff' : '#94A3B8', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 'bold' }}
        >
          <Clock size={16} />
          <span>Audit Log ({auditLogs.length})</span>
        </button>
      </div>

      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: '100px' }}>
          <div className="spinner" style={{ width: '40px', height: '40px', border: '4px solid rgba(255,255,255,0.1)', borderTop: '4px solid var(--color-accent)', borderRadius: '50%', animation: 'spin 1s linear infinite' }}></div>
        </div>
      ) : activeTab === 'popups' ? (
        
        /* POPUPS TABLE / LIST */
        <div className="glass-panel table-container">
          {popups.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '64px', color: 'var(--color-text-muted)' }}>
              <Bell size={48} style={{ opacity: 0.3, marginBottom: '16px' }} />
              <p>No popup broadcast campaigns found. Create one to get started!</p>
            </div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Title / Campaign</th>
                  <th>Type</th>
                  <th>Priority</th>
                  <th>Frequency</th>
                  <th>Target Rules</th>
                  <th>Status</th>
                  <th>Analytics (Views/Clicks)</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {popups.map(p => {
                  const ctr = p.analytics?.seen > 0 ? ((p.analytics.clicked / p.analytics.seen) * 100).toFixed(1) : '0.0';
                  return (
                    <tr key={p.id}>
                      <td>
                        <div style={{ fontWeight: 'bold' }}>{p.title?.en || 'Untitled'}</div>
                        <div style={{ fontSize: '11px', color: 'var(--color-text-muted)', marginTop: '4px' }}>
                          ID: {p.id.slice(0, 8)}... | Created: {p.createdAt ? new Date(p.createdAt).toLocaleDateString() : 'N/A'}
                        </div>
                      </td>
                      <td>
                        <span className={getTypeBadgeClass(p.type)}>{p.type}</span>
                      </td>
                      <td>
                        <span className={getPriorityBadgeClass(p.priority)}>{p.priority}</span>
                      </td>
                      <td>
                        <span className="frequency-label" style={{ fontSize: '13px' }}>{p.frequency?.replace('_', ' ')}</span>
                      </td>
                      <td>
                        <div className="targeting-summary-cell" style={{ fontSize: '12px', color: 'var(--color-text-muted)' }}>
                          <div>Lang: {(p.targeting?.languages || []).join(', ')}</div>
                          {p.targeting?.userTypes?.length > 0 && <div>Plan: {p.targeting.userTypes.join(', ')}</div>}
                          {p.targeting?.platforms?.length > 0 && <div>OS: {p.targeting.platforms.join(', ')}</div>}
                        </div>
                      </td>
                      <td>
                        <span className={`status-cell ${p.status === 'active' ? 'text-green' : p.status === 'paused' ? 'text-orange' : 'text-muted'}`} style={{ fontWeight: 'bold' }}>
                          {p.status === 'active' ? 'Active' : p.status === 'paused' ? 'Paused' : 'Draft'}
                        </span>
                      </td>
                      <td>
                        <div className="analytics-cell" style={{ fontSize: '12px' }}>
                          <div>Seen: <span style={{ color: '#fff', fontWeight: 'bold' }}>{p.analytics?.seen || 0}</span></div>
                          <div>Clicks: <span style={{ color: 'var(--color-accent)', fontWeight: 'bold' }}>{p.analytics?.clicked || 0}</span> ({ctr}%)</div>
                        </div>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <div className="actions-cell-buttons" style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                          {/* Toggle publish/pause */}
                          {p.status !== 'draft' && (
                            <button 
                              className="icon-btn-small" 
                              onClick={() => handleToggleStatus(p)} 
                              title={p.status === 'active' ? 'Pause Campaign' : 'Resume Campaign'}
                              style={{ background: 'transparent', border: 'none', color: 'var(--color-text-muted)', cursor: 'pointer', padding: '4px' }}
                            >
                              {p.status === 'active' ? <Pause size={16} /> : <Play size={16} />}
                            </button>
                          )}
                          
                          {/* Edit */}
                          <button 
                            className="icon-btn-small" 
                            onClick={() => handleOpenEdit(p)} 
                            title="Edit Campaign"
                            style={{ background: 'transparent', border: 'none', color: 'var(--color-text-muted)', cursor: 'pointer', padding: '4px' }}
                          >
                            <Edit2 size={16} />
                          </button>
                          
                          {/* Duplicate */}
                          <button 
                            className="icon-btn-small" 
                            onClick={() => handleDuplicate(p)} 
                            title="Duplicate/Clone"
                            style={{ background: 'transparent', border: 'none', color: 'var(--color-text-muted)', cursor: 'pointer', padding: '4px' }}
                          >
                            <Copy size={16} />
                          </button>

                          {/* Delete */}
                          <button 
                            className="icon-btn-small text-red" 
                            onClick={() => handleDelete(p)} 
                            title="Delete Campaign"
                            style={{ background: 'transparent', border: 'none', color: '#EF4444', cursor: 'pointer', padding: '4px' }}
                          >
                            <Trash2 size={16} />
                          </button>
                          
                          {/* Deploy / Target Broadcast */}
                          <button 
                            className="icon-btn-small"
                            onClick={() => {
                              setDeployingPopup(p);
                              setDeployAudienceType(p.targeting?.userTypes?.includes('premium') ? 'premium' : p.targeting?.userTypes?.includes('free') ? 'free' : p.targeting?.userTypes?.includes('unregistered') ? 'unregistered' : p.targeting?.emails?.length > 0 ? 'emails' : 'all');
                              setDeployEmails(p.targeting?.emails ? p.targeting.emails.join(', ') : '');
                              setShowDeployModal(true);
                            }}
                            title="Deploy Campaign / Target Audience"
                            style={{ background: 'transparent', border: 'none', color: '#8B5CF6', cursor: 'pointer', padding: '4px' }}
                          >
                            <Megaphone size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>

                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      ) : (
        
        /* AUDIT LOG TAB */
        <div className="glass-panel table-container">
          {auditLogs.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '64px', color: 'var(--color-text-muted)' }}>
              <Clock size={48} style={{ opacity: 0.3, marginBottom: '16px' }} />
              <p>No audit logging records logged yet.</p>
            </div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Administrator</th>
                  <th>Action</th>
                  <th>Details</th>
                </tr>
              </thead>
              <tbody>
                {auditLogs.map(l => (
                  <tr key={l.id}>
                    <td style={{ color: 'var(--color-text-muted)', fontSize: '13px' }}>{new Date(l.timestamp).toLocaleString()}</td>
                    <td><span style={{ fontWeight: 'bold' }}>{l.adminEmail}</span></td>
                    <td>
                      <span className={`audit-badge badge-action-${l.action}`}>
                        {l.action?.toUpperCase()}
                      </span>
                    </td>
                    <td style={{ fontSize: '13px', color: 'var(--color-text-muted)' }}>{l.details}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* CREATE / EDIT OVERLAY MODAL FORM */}
      {showFormModal && (
        <div className="modal-overlay">
          <div className="form-modal-container glass-panel">
            
            {/* Modal Header */}
            <div className="modal-header">
              <h2>{selectedPopup ? 'Edit Broadcast Campaign' : 'Create Broadcast Campaign'}</h2>
              <button className="icon-btn-small" onClick={() => setShowFormModal(false)} style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>

            {/* Modal Body Grid */}
            <div className="modal-grid-body">
              
              {/* Settings Form */}
              <form onSubmit={handleSaveForm} className="modal-edit-form">
                
                {/* Template Selection Helper */}
                {!selectedPopup && (
                  <div className="form-group-full">
                    <label className="label">Pre-made Campaign Templates</label>
                    <select 
                      className="input-field" 
                      defaultValue="" 
                      onChange={(e) => handleApplyTemplate(e.target.value)}
                    >
                      <option value="" disabled>Choose a template to autofill fields...</option>
                      <option value="app_update">App Update Broadcast Alert</option>
                      <option value="maintenance">Scheduled System Maintenance notice</option>
                      <option value="premium_promo">30% Off Premium Promotion</option>
                      <option value="new_book">New Book Release Announcement (Generic)</option>
                    </select>
                  </div>
                )}

                {/* Auto-fill from Recent Books list */}
                {!selectedPopup && recentBooks.length > 0 && (
                  <div className="form-group-full" style={{ marginTop: '12px', opacity: form.type === 'new_book' ? 1 : 0.5 }}>
                    <label className="label">Or Auto-Fill from Recent Books (Last 5 Added)</label>
                    <select 
                      className="input-field" 
                      defaultValue="" 
                      disabled={form.type !== 'new_book'}
                      onChange={(e) => handleApplyBookTemplate(e.target.value)}
                    >
                      <option value="" disabled>
                        {form.type === 'new_book' 
                          ? 'Select a recent book summary to build popup...' 
                          : 'Select "New Book Release" template or type first...'}
                      </option>
                      {recentBooks.map(book => (
                        <option key={book.id} value={book.id}>
                          {book.title?.en || 'Untitled'} - By {book.author?.en || 'Unknown'}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                {/* Form fields: Type, Priority, Status, Frequency */}
                <div className="form-row-2">
                  <div>
                    <label className="label">Overlay Type</label>
                    <select 
                      className="input-field" 
                      value={form.type} 
                      onChange={e => setForm({ ...form, type: e.target.value })}
                    >
                      <option value="info">Info / Tip</option>
                      <option value="update">System Update</option>
                      <option value="warning">Critical Alert / Warning</option>
                      <option value="promotion">Promo / Offers</option>
                      <option value="new_book">New Book release</option>
                      <option value="subscription">Paywall / Subscription</option>
                      <option value="maintenance">Maintenance alert</option>
                    </select>
                  </div>
                  <div>
                    <label className="label">Priority Level</label>
                    <select 
                      className="input-field" 
                      value={form.priority} 
                      onChange={e => setForm({ ...form, priority: e.target.value })}
                    >
                      <option value="normal">Normal (Ambient overlays)</option>
                      <option value="important">Important (Stricter validation)</option>
                      <option value="urgent">Urgent (Immediate fullscreen modal)</option>
                    </select>
                  </div>
                </div>

                <div className="form-row-2" style={{ marginTop: '12px' }}>
                  <div>
                    <label className="label">Campaign Frequency</label>
                    <select 
                      className="input-field" 
                      value={form.frequency} 
                      onChange={e => setForm({ ...form, frequency: e.target.value })}
                    >
                      <option value="once">Display once only</option>
                      <option value="every_open">Every time app is opened</option>
                      <option value="once_daily">Once per day</option>
                      <option value="weekly">Once per week</option>
                      <option value="until_dismissed">Every open until user clicks dismiss</option>
                    </select>
                  </div>
                  <div>
                    <label className="label">Status</label>
                    <select 
                      className="input-field" 
                      value={form.status} 
                      onChange={e => setForm({ ...form, status: e.target.value })}
                    >
                      <option value="draft">Draft (Private)</option>
                      <option value="active">Active (Live according to scheduling)</option>
                      <option value="paused">Paused (Inactive)</option>
                    </select>
                  </div>
                </div>

                {/* Localized Content Tabs: English, Arabic, Kurdish */}
                <h3 className="section-title">Localized Broadcast Content</h3>
                
                {/* Tab select Buttons */}
                <div className="lang-tabs-buttons">
                  <button type="button" className={`lang-tab-btn ${previewLang === 'en' ? 'active' : ''}`} onClick={() => setPreviewLang('en')}>English</button>
                  <button type="button" className={`lang-tab-btn ${previewLang === 'ar' ? 'active' : ''}`} onClick={() => setPreviewLang('ar')}>العربية</button>
                  <button type="button" className={`lang-tab-btn ${previewLang === 'ku' ? 'active' : ''}`} onClick={() => setPreviewLang('ku')}>کوردی (سۆرانی)</button>
                </div>

                <div className="localized-content-group">
                  <div>
                    <label className="label">Broadcast Title ({previewLang.toUpperCase()})</label>
                    <input 
                      type="text" 
                      className="input-field" 
                      dir={previewLang === 'en' ? 'ltr' : 'rtl'}
                      value={form.title[previewLang]} 
                      onChange={e => {
                        const updatedTitle = { ...form.title, [previewLang]: e.target.value };
                        setForm({ ...form, title: updatedTitle });
                      }}
                      required
                    />
                  </div>
                  <div style={{ marginTop: '12px' }}>
                    <label className="label">Broadcast Body ({previewLang.toUpperCase()})</label>
                    <textarea 
                      className="input-field" 
                      rows="3"
                      dir={previewLang === 'en' ? 'ltr' : 'rtl'}
                      value={form.body[previewLang]} 
                      onChange={e => {
                        const updatedBody = { ...form.body, [previewLang]: e.target.value };
                        setForm({ ...form, body: updatedBody });
                      }}
                      required
                    />
                  </div>
                  <div style={{ marginTop: '12px' }}>
                    <label className="label">Action Button Text ({previewLang.toUpperCase()})</label>
                    <input 
                      type="text" 
                      className="input-field" 
                      dir={previewLang === 'en' ? 'ltr' : 'rtl'}
                      value={form.actionText[previewLang]} 
                      onChange={e => {
                        const updatedBtn = { ...form.actionText, [previewLang]: e.target.value };
                        setForm({ ...form, actionText: updatedBtn });
                      }}
                    />
                  </div>
                </div>

                {/* Media & Click Links */}
                <h3 className="section-title">Media & External Triggers</h3>
                <div className="form-row-2">
                  <div>
                    <label className="label">Image URL (Optional)</label>
                    <input 
                      type="url" 
                      className="input-field" 
                      placeholder="https://example.com/banner.png"
                      value={form.imageUrl} 
                      onChange={e => setForm({ ...form, imageUrl: e.target.value })}
                    />
                  </div>
                  <div>
                    <label className="label">Click Action URL (Optional)</label>
                    <input 
                      type="text" 
                      className="input-field" 
                      placeholder="https://... or partwk://paywall"
                      value={form.actionUrl} 
                      onChange={e => setForm({ ...form, actionUrl: e.target.value })}
                    />
                  </div>
                </div>

                {/* Scheduling */}
                <h3 className="section-title">Scheduling Rules</h3>
                <div className="form-row-2">
                  <div>
                    <label className="label">Start Date & Time (Optional)</label>
                    <input 
                      type="datetime-local" 
                      className="input-field"
                      value={form.scheduling.startDate} 
                      onChange={e => setForm({ ...form, scheduling: { ...form.scheduling, startDate: e.target.value } })}
                    />
                  </div>
                  <div>
                    <label className="label">End Date & Time (Optional)</label>
                    <input 
                      type="datetime-local" 
                      className="input-field"
                      value={form.scheduling.endDate} 
                      onChange={e => setForm({ ...form, scheduling: { ...form.scheduling, endDate: e.target.value } })}
                    />
                  </div>
                </div>

                {/* Targeting filters */}
                <h3 className="section-title">Campaign Targeting Criteria</h3>
                
                {/* Language targeting checkboxes */}
                <div className="form-group-checkboxes" style={{ marginBottom: '16px' }}>
                  <span className="label" style={{ display: 'block', marginBottom: '8px' }}>Target User Languages</span>
                  <div className="checkboxes-row" style={{ display: 'flex', gap: '20px' }}>
                    <label className="checkbox-label" style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#fff' }}>
                      <input 
                        type="checkbox" 
                        checked={form.targeting.languages.includes('en')} 
                        onChange={(e) => {
                          const langs = e.target.checked 
                            ? [...form.targeting.languages, 'en'] 
                            : form.targeting.languages.filter(l => l !== 'en');
                          setForm({ ...form, targeting: { ...form.targeting, languages: langs } });
                        }}
                      />
                      <span>English (EN)</span>
                    </label>
                    <label className="checkbox-label" style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#fff' }}>
                      <input 
                        type="checkbox" 
                        checked={form.targeting.languages.includes('ar')} 
                        onChange={(e) => {
                          const langs = e.target.checked 
                            ? [...form.targeting.languages, 'ar'] 
                            : form.targeting.languages.filter(l => l !== 'ar');
                          setForm({ ...form, targeting: { ...form.targeting, languages: langs } });
                        }}
                      />
                      <span>Arabic (AR)</span>
                    </label>
                    <label className="checkbox-label" style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#fff' }}>
                      <input 
                        type="checkbox" 
                        checked={form.targeting.languages.includes('ku')} 
                        onChange={(e) => {
                          const langs = e.target.checked 
                            ? [...form.targeting.languages, 'ku'] 
                            : form.targeting.languages.filter(l => l !== 'ku');
                          setForm({ ...form, targeting: { ...form.targeting, languages: langs } });
                        }}
                      />
                      <span>Kurdish (KU)</span>
                    </label>
                  </div>
                </div>

                {/* Targeting inputs: plans, platforms, versions */}
                <div className="form-row-3">
                  <div>
                    <label className="label">Subscription Plans (comma-sep)</label>
                    <input 
                      type="text" 
                      className="input-field" 
                      placeholder="free, premium (empty=all)"
                      value={form.targeting.userTypes.join(', ')} 
                      onChange={e => {
                        const vals = e.target.value.split(',').map(s => s.trim().toLowerCase()).filter(s => s.length > 0);
                        setForm({ ...form, targeting: { ...form.targeting, userTypes: vals } });
                      }}
                    />
                  </div>
                  <div>
                    <label className="label">Target OS Platforms (comma-sep)</label>
                    <input 
                      type="text" 
                      className="input-field" 
                      placeholder="ios, android (empty=all)"
                      value={form.targeting.platforms.join(', ')} 
                      onChange={e => {
                        const vals = e.target.value.split(',').map(s => s.trim().toLowerCase()).filter(s => s.length > 0);
                        setForm({ ...form, targeting: { ...form.targeting, platforms: vals } });
                      }}
                    />
                  </div>
                  <div>
                    <label className="label">App Version (comma-sep)</label>
                    <input 
                      type="text" 
                      className="input-field" 
                      placeholder="2.0, 2.1 (empty=all)"
                      value={form.targeting.appVersions.join(', ')} 
                      onChange={e => {
                        const vals = e.target.value.split(',').map(s => s.trim()).filter(s => s.length > 0);
                        setForm({ ...form, targeting: { ...form.targeting, appVersions: vals } });
                      }}
                    />
                  </div>
                </div>

                {/* Specific Targeting: emails */}
                <div className="form-group-full" style={{ marginTop: '12px' }}>
                  <label className="label">Target Specific User Emails (Comma-separated list for private/testing)</label>
                  <textarea 
                    className="input-field" 
                    rows="2"
                    placeholder="user1@email.com, user2@email.com"
                    value={form.targeting.emails.join(', ')} 
                    onChange={e => {
                      const vals = e.target.value.split(',').map(s => s.trim().toLowerCase()).filter(s => s.length > 0);
                      setForm({ ...form, targeting: { ...form.targeting, emails: vals } });
                    }}
                  />
                </div>

                {/* Submit buttons */}
                <div className="form-submit-actions" style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '24px' }}>
                  <button type="button" className="btn-outline" onClick={() => setShowFormModal(false)}>Cancel</button>
                  <button type="submit" className="btn-primary">
                    <Save size={16} />
                    <span>Save Campaign</span>
                  </button>
                </div>

              </form>

              {/* LIVE PHONE SCREEN OVERLAY PREVIEW */}
              <div className="live-preview-container" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <span className="label">Real-Time App Preview ({previewLang.toUpperCase()})</span>
                
                {/* Phone mockup */}
                <div className="phone-mockup" style={{ width: '280px', height: '560px', border: '8px solid #1E293B', borderRadius: '32px', position: 'relative', background: '#090D16', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
                  
                  {/* Phone Status Bar */}
                  <div className="phone-status-bar" style={{ height: '28px', background: '#000', color: '#94A3B8', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 16px', fontSize: '11px', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <span>9:41</span>
                    <div className="phone-notch" style={{ width: '80px', height: '16px', background: '#000', borderRadius: '0 0 10px 10px', position: 'absolute', left: '50%', transform: 'translateX(-50%)', top: 0 }}></div>
                    <div style={{ display: 'flex', gap: '4px', fontSize: '9px' }}>
                      <span>LTE</span>
                      <span>100%</span>
                    </div>
                  </div>

                  {/* Reusable App Alert Dialog Mock */}
                  <div className="phone-screen-content" style={{ flex: 1, padding: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(0,0,0,0.6)' }}>
                    
                    {/* Dialog body */}
                    <div className="preview-app-dialog glass-panel" dir={previewLang === 'en' ? 'ltr' : 'rtl'} style={{ padding: '16px', width: '100%', borderRadius: '16px', display: 'flex', flexDirection: 'column', gap: '12px', border: '1px solid rgba(255,255,255,0.1)' }}>
                      
                      {/* Dynamic Priority Icon / Header */}
                      <div className={`preview-priority-header ${form.priority}`} style={{ alignSelf: 'center', display: 'flex', justifyContent: 'center', width: '48px', height: '48px', borderRadius: '50%', background: form.priority === 'urgent' ? 'rgba(239, 68, 68, 0.15)' : form.priority === 'important' ? 'rgba(245, 158, 11, 0.15)' : 'rgba(13, 148, 136, 0.15)', color: form.priority === 'urgent' ? '#EF4444' : form.priority === 'important' ? '#F59E0B' : '#0D9488', alignItems: 'center' }}>
                        {form.priority === 'urgent' ? (
                          <ShieldAlert size={28} />
                        ) : form.priority === 'important' ? (
                          <AlertTriangle size={28} />
                        ) : (
                          <Info size={28} />
                        )}
                      </div>

                      {/* Title */}
                      <h4 className="preview-dialog-title" style={{ fontSize: '15px', fontWeight: 'bold', textAlign: 'center', color: '#fff' }}>
                        {form.title[previewLang] || 'Broadcast Title'}
                      </h4>

                      {/* Image banner inside modal if uploaded */}
                      {form.imageUrl && (
                        <div className="preview-image-banner" style={{ width: '100%', height: '80px', borderRadius: '8px', overflow: 'hidden', background: '#131B2E', display: 'flex' }}>
                          <img src={form.imageUrl} alt="Banner" style={{ width: '100%', height: '100%', objectFit: 'cover' }} onError={(e) => e.target.style.display = 'none'} />
                        </div>
                      )}

                      {/* Body description text */}
                      <p className="preview-dialog-body" style={{ fontSize: '11px', color: '#94A3B8', textAlign: 'center', lineHeight: '1.4' }}>
                        {form.body[previewLang] || 'This is the description broadcast body content. Localized alignments automatically support Arabic and Kurdish.'}
                      </p>

                      {/* Buttons section */}
                      <div className="preview-dialog-actions" style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '4px' }}>
                        {form.actionUrl && (
                          <button 
                            type="button" 
                            className={`preview-btn-action ${form.priority}`} 
                            style={{ 
                              padding: '8px 12px', 
                              borderRadius: '8px', 
                              border: 'none', 
                              color: '#fff', 
                              fontWeight: 'bold', 
                              fontSize: '11px', 
                              cursor: 'pointer',
                              background: form.priority === 'urgent' ? '#EF4444' : form.priority === 'important' ? '#F59E0B' : '#0D9488'
                            }}
                          >
                            {form.actionText[previewLang] || 'Open Link'}
                          </button>
                        )}
                        <button 
                          type="button" 
                          className="preview-btn-close"
                          style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.08)', color: '#94A3B8', fontWeight: 'bold', fontSize: '11px', background: 'transparent', cursor: 'pointer' }}
                        >
                          {previewLang === 'ku' ? 'داخستن' : previewLang === 'ar' ? 'إغلاق' : 'Close'}
                        </button>
                      </div>

                    </div>
                  </div>
                  
                  {/* Phone Home indicator */}
                  <div className="phone-home-indicator" style={{ height: '4px', width: '100px', background: 'rgba(255,255,255,0.2)', borderRadius: '2px', alignSelf: 'center', marginBottom: '8px' }}></div>

                </div>
              </div>

            </div>

          </div>
        </div>
      )}

      {/* DEPLOY AUDIENCE TARGET MODAL */}
      {showDeployModal && deployingPopup && (
        <div className="modal-overlay">
          <div className="form-modal-container glass-panel" style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h2>Deploy Campaign Target</h2>
              <button className="icon-btn-small" onClick={() => setShowDeployModal(false)} style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleDeployCampaign} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ padding: '12px', background: 'rgba(13, 148, 136, 0.1)', borderRadius: '8px', border: '1px solid rgba(13, 148, 136, 0.2)' }}>
                <div style={{ fontWeight: 'bold', color: '#14B8A6', fontSize: '14px' }}>Campaign:</div>
                <div style={{ color: '#fff', fontSize: '15px', marginTop: '4px', fontWeight: '500' }}>{deployingPopup.title?.en || 'Untitled Campaign'}</div>
              </div>

              <div>
                <label className="label">Deploy Target Audience</label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: '8px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#fff', cursor: 'pointer' }}>
                    <input type="radio" name="deployTarget" value="all" checked={deployAudienceType === 'all'} onChange={() => setDeployAudienceType('all')} />
                    <div>
                      <div style={{ fontWeight: 'bold', fontSize: '13px' }}>All Users</div>
                      <div style={{ fontSize: '11px', color: '#94A3B8' }}>Deploy to all registered & guest users on all platforms</div>
                    </div>
                  </label>
                  
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#fff', cursor: 'pointer' }}>
                    <input type="radio" name="deployTarget" value="premium" checked={deployAudienceType === 'premium'} onChange={() => setDeployAudienceType('premium')} />
                    <div>
                      <div style={{ fontWeight: 'bold', fontSize: '13px' }}>Premium Users Only</div>
                      <div style={{ fontSize: '11px', color: '#94A3B8' }}>Target active premium subscription accounts</div>
                    </div>
                  </label>
                  
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#fff', cursor: 'pointer' }}>
                    <input type="radio" name="deployTarget" value="free" checked={deployAudienceType === 'free'} onChange={() => setDeployAudienceType('free')} />
                    <div>
                      <div style={{ fontWeight: 'bold', fontSize: '13px' }}>Free Users Only</div>
                      <div style={{ fontSize: '11px', color: '#94A3B8' }}>Target free subscription basic accounts</div>
                    </div>
                  </label>

                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#fff', cursor: 'pointer' }}>
                    <input type="radio" name="deployTarget" value="unregistered" checked={deployAudienceType === 'unregistered'} onChange={() => setDeployAudienceType('unregistered')} />
                    <div>
                      <div style={{ fontWeight: 'bold', fontSize: '13px' }}>Unregistered Guests Only</div>
                      <div style={{ fontSize: '11px', color: '#94A3B8' }}>Target unregistered users who haven't logged in</div>
                    </div>
                  </label>
                  
                  <label style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#fff', cursor: 'pointer' }}>
                    <input type="radio" name="deployTarget" value="emails" checked={deployAudienceType === 'emails'} onChange={() => setDeployAudienceType('emails')} />
                    <div>
                      <div style={{ fontWeight: 'bold', fontSize: '13px' }}>Specific Email List (Test target)</div>
                      <div style={{ fontSize: '11px', color: '#94A3B8' }}>Target specific admin/user email accounts</div>
                    </div>
                  </label>
                </div>
              </div>

              {deployAudienceType === 'emails' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label className="label">Comma-separated Emails</label>
                  <textarea 
                    className="input-field" 
                    rows="3" 
                    placeholder="user1@example.com, user2@example.com"
                    value={deployEmails} 
                    onChange={e => setDeployEmails(e.target.value)}
                    required
                  />
                </div>
              )}

              <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '12px' }}>
                <button type="button" className="btn-outline" onClick={() => setShowDeployModal(false)}>Cancel</button>
                <button type="submit" className="btn-primary" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Send size={16} />
                  <span>Launch Deployment</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
};

export default PopupManagement;
