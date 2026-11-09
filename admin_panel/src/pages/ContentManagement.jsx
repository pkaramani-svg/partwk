import { useState, useEffect } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Plus, Edit2, Trash2, X, UploadCloud, Music, FileText, Sparkles, ArrowUp, ArrowDown } from 'lucide-react';
import { fetchBooks, getBookForEditing, setBookLanguageVisibility, addBook, uploadFile, updateBook, deleteBook, addQuizData, addFlashcardsData, checkAiDataExists, publishBooksBatch } from '../services/api';
import './UsersManagement.css'; // Reuse table styles

const categoryNames = {
  'cat-productivity': 'Productivity',
  'cat-psychology': 'Psychology',
  'cat-personal-development': 'Personal Development',
  'cat-business': 'Business',
  'cat-leadership': 'Leadership',
  'cat-money-investing': 'Money & Investing',
  'cat-communication': 'Communication',
  'cat-health-wellness': 'Health & Wellness',
  'cat-technology-innovation': 'Technology & Innovation',
  'cat-biography-memoir': 'Biography & Memoir',
  'cat-modern-wisdom': 'Modern Wisdom',
  'cat-history-big-ideas': 'History & Big Ideas',
};

const ContentManagement = () => {
  const [searchTerm, setSearchTerm] = useOutletContext();
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [editingBookId, setEditingBookId] = useState(null);
  const [editingBookData, setEditingBookData] = useState(null);
  const [isGeneratingAi, setIsGeneratingAi] = useState(false);
  const [aiDataExists, setAiDataExists] = useState(false);
  const [pendingAiData, setPendingAiData] = useState({});
  const [isPublished, setIsPublished] = useState(false);
  const [selectedBookIds, setSelectedBookIds] = useState([]);

  // Sorting State
  const [sortField, setSortField] = useState('title');
  const [sortDirection, setSortDirection] = useState('asc');

  const handleSort = (field) => {
    if (sortField === field) {
      setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const filteredBooks = books.filter(book => {
    const term = (searchTerm || '').toLowerCase();
    if (!term) return true;
    
    const titleMatch = Object.values(book.title || {}).some(val => (val || '').toLowerCase().includes(term));
    const authorMatch = Object.values(book.author || {}).some(val => (val || '').toLowerCase().includes(term));
    const descMatch = Object.values(book.description || {}).some(val => (val || '').toLowerCase().includes(term));
    const bookCats = Array.isArray(book.categories) && book.categories.length > 0
      ? book.categories
      : (Array.isArray(book.categoryIds) ? book.categoryIds : (book.category ? [book.category] : []));
    const catMatch = bookCats.some(catId => (categoryNames[catId] || catId).toLowerCase().includes(term));
    
    return titleMatch || authorMatch || descMatch || catMatch;
  });

  const sortedBooks = [...filteredBooks].sort((a, b) => {
    if (!sortField) return 0;
    
    let aVal, bVal;
    
    if (sortField === 'title') {
      aVal = (a.title?.en || a.title?.ku || a.title?.ar || '').toLowerCase();
      bVal = (b.title?.en || b.title?.ku || b.title?.ar || '').toLowerCase();
    } else if (sortField === 'category') {
      const getCatNames = (item) => {
        const cats = Array.isArray(item.categories) && item.categories.length > 0
          ? item.categories
          : (Array.isArray(item.categoryIds) ? item.categoryIds : (item.category ? [item.category] : []));
        return cats.map(id => categoryNames[id] || id).join(', ');
      };
      const aCat = getCatNames(a);
      const bCat = getCatNames(b);
      aVal = aCat.toLowerCase();
      bVal = bCat.toLowerCase();
    } else if (sortField === 'languages') {
      aVal = Object.keys(a.title || {}).length;
      bVal = Object.keys(b.title || {}).length;
    } else if (sortField === 'chapters') {
      aVal = a.chapterSummaries ? Object.values(a.chapterSummaries)[0]?.length || 0 : 0;
      bVal = b.chapterSummaries ? Object.values(b.chapterSummaries)[0]?.length || 0 : 0;
    } else if (sortField === 'duration') {
      aVal = a.duration || 0;
      bVal = b.duration || 0;
    } else if (sortField === 'dateAdded') {
      aVal = a.createdAt || '';
      bVal = b.createdAt || '';
    } else if (sortField === 'dateEdited') {
      aVal = a.updatedAt || '';
      bVal = b.updatedAt || '';
    } else if (sortField === 'isPublished') {
      aVal = a.isPublished !== false ? 1 : 0;
      bVal = b.isPublished !== false ? 1 : 0;
    }
    
    if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1;
    if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1;
    return 0;
  });

  // Form State
  const [lang, setLang] = useState('en');
  const [title, setTitle] = useState('');
  const [author, setAuthor] = useState('');
  const [description, setDescription] = useState('');
  const [selectedCategories, setSelectedCategories] = useState(['cat-productivity']);
  const categoryId = selectedCategories[0] || 'cat-productivity';
  const [isPremium, setIsPremium] = useState(false);
  const [isDownloadable, setIsDownloadable] = useState(true);
  
  // Media Files
  const [coverFile, setCoverFile] = useState(null);
  const [existingCoverUrl, setExistingCoverUrl] = useState(null);

  // Chapters (each with its own audio)
  const [chapters, setChapters] = useState([{ title: 'Intro', content: '', audioFile: null, duration: 0 }]);

  const loadBooks = async () => {
    try {
      const data = await fetchBooks();
      setBooks(data);
    } catch (error) {
      console.error("Error fetching books:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBooks();
  }, []);

  const handleBatchPublish = async (publishState) => {
    if (selectedBookIds.length === 0) return;
    const actionText = publishState ? 'publish' : 'unpublish (set to draft)';
    if (window.confirm(`Are you sure you want to ${actionText} the ${selectedBookIds.length} selected book(s)?`)) {
      try {
        setIsSubmitting(true);
        await publishBooksBatch(selectedBookIds, publishState);
        setSelectedBookIds([]);
        await loadBooks();
        alert(`Successfully updated status for selected books.`);
      } catch (error) {
        console.error("Batch publish error:", error);
        alert(`Failed to update books: ${error.message || "Unknown error"}`);
      } finally {
        setIsSubmitting(false);
      }
    }
  };

  const checkAiStatus = async (bookId, selectedLang) => {
    if (!bookId) {
      setAiDataExists(false);
      return;
    }
    try {
      const exists = await checkAiDataExists(bookId, selectedLang);
      setAiDataExists(exists);
    } catch (e) {
      console.error(e);
    }
  };

  useEffect(() => {
    if (showModal) {
      if (pendingAiData[lang]) {
        setAiDataExists(true);
      } else {
        checkAiStatus(editingBookId, lang);
      }
    }
  }, [editingBookId, lang, showModal, pendingAiData]);

  const handleAddChapter = () => {
    const nextChapterNumber = chapters.length;
    setChapters([...chapters, { title: `Key Point ${nextChapterNumber}`, content: '', audioFile: null, duration: 0 }]);
  };

  const updateChapter = (index, field, value) => {
    const newChapters = [...chapters];
    newChapters[index][field] = value;
    setChapters(newChapters);
  };

  const handleChapterAudioChange = (index, e) => {
    const file = e.target.files[0];
    if (file) {
      const audioUrl = URL.createObjectURL(file);
      const audio = new Audio(audioUrl);
      audio.onloadedmetadata = () => {
        const newChapters = [...chapters];
        newChapters[index].audioFile = file;
        newChapters[index].duration = Math.round(audio.duration);
        newChapters[index].audioPreviewUrl = audioUrl;
        setChapters(newChapters);
      };
    }
  };

  const removeChapter = (index) => {
    const newChapters = chapters.filter((_, i) => i !== index);
    setChapters(newChapters);
  };

  const handleMoveChapter = (index, direction) => {
    if (direction === 'up' && index > 0) {
      const newChapters = [...chapters];
      const temp = newChapters[index];
      newChapters[index] = newChapters[index - 1];
      newChapters[index - 1] = temp;
      setChapters(newChapters);
    } else if (direction === 'down' && index < chapters.length - 1) {
      const newChapters = [...chapters];
      const temp = newChapters[index];
      newChapters[index] = newChapters[index + 1];
      newChapters[index + 1] = temp;
      setChapters(newChapters);
    }
  };

  const resetForm = () => {
    setLang('en');
    setTitle('');
    setAuthor('');
    setDescription('');
    setSelectedCategories(['cat-productivity']);
    setIsPremium(false);
    setIsDownloadable(true);
    setIsPublished(false);
    setCoverFile(null);
    setExistingCoverUrl(null);
    setChapters([{ title: 'Intro', content: '', audioFile: null, duration: 0 }]);
    setEditingBookId(null);
    setEditingBookData(null);
    setPendingAiData({});
  };

  const handleLanguageChange = (selectedLang) => {
    setLang(selectedLang);
    
    if (editingBookId) {
      const currentBook = editingBookData;
      if (currentBook) {
        setTitle(currentBook.title?.[selectedLang] || '');
        setAuthor(currentBook.author?.[selectedLang] || '');
        setDescription(currentBook.description?.[selectedLang] || '');

        let coverUrl = '';
        if (currentBook.coverImageUrl) {
          if (typeof currentBook.coverImageUrl === 'string') {
            coverUrl = currentBook.coverImageUrl;
          } else if (typeof currentBook.coverImageUrl === 'object') {
            coverUrl = currentBook.coverImageUrl[selectedLang] || '';
          }
        }
        setExistingCoverUrl(coverUrl);

        const existingChapters = currentBook.chapterSummaries?.[selectedLang];
        if (existingChapters && existingChapters.length > 0) {
          setChapters(existingChapters.map(ch => ({
            title: ch.title || '',
            content: ch.content || '',
            audioFile: null, // can't pre-fill file
            audioUrl: ch.audioUrl || '',
            duration: ch.duration || 0
          })));
        } else {
          setChapters([{ title: 'Intro', content: '', audioFile: null, duration: 0 }]);
        }
      }
    }
  };

  const openEditModal = async (catalogueBook) => {
    let book;
    try { book = await getBookForEditing(catalogueBook.id); }
    catch (error) { alert(`Failed to load book for editing: ${error.message}`); return; }
    setEditingBookData(book);
    const initialLang = Object.keys(book.title || {})[0] || 'en';
    setLang(initialLang);
    setTitle(book.title?.[initialLang] || '');
    setAuthor(book.author?.[initialLang] || '');
    const rawCategories = Array.isArray(book.categories) && book.categories.length > 0
      ? book.categories
      : (Array.isArray(book.categoryIds) && book.categoryIds.length > 0
        ? book.categoryIds
        : (book.category ? [book.category] : ['cat-productivity']));
    const bookCategories = Array.from(new Set(rawCategories.filter(Boolean)));
    setSelectedCategories(bookCategories.length > 0 ? bookCategories : ['cat-productivity']);
    setIsPremium(book.isPremium || false);
    setIsDownloadable(book.isDownloadable !== false);
    setIsPublished(book.isPublished !== false);
    
    setCoverFile(null);
    
    let coverUrl = '';
    if (book.coverImageUrl) {
      if (typeof book.coverImageUrl === 'string') {
        coverUrl = book.coverImageUrl;
      } else if (typeof book.coverImageUrl === 'object') {
        coverUrl = book.coverImageUrl[initialLang] || book.coverImageUrl['en'] || Object.values(book.coverImageUrl)[0] || '';
      }
    }
    setExistingCoverUrl(coverUrl);

    // Pre-fill chapters
    const existingChapters = book.chapterSummaries?.[initialLang];
    if (existingChapters && existingChapters.length > 0) {
      setChapters(existingChapters.map(ch => ({
        title: ch.title || '',
        content: ch.content || '',
        audioFile: null, // can't pre-fill file
        audioUrl: ch.audioUrl || '',
        duration: ch.duration || 0
      })));
    } else {
      setChapters([{ title: 'Intro', content: '', audioFile: null, duration: 0 }]);
    }

    setEditingBookId(book.id);
    setShowModal(true);
  };

  const handleDeleteBook = async (bookId) => {
    if (window.confirm("Are you sure you want to permanently delete this book? This action cannot be undone.")) {
      try {
        await deleteBook(bookId);
        await loadBooks(); // Refresh table
      } catch (error) {
        console.error("Error deleting book:", error);
        alert(`Failed to delete book: ${error.message}`);
      }
    }
  };

  const handleToggleHideLanguage = async (book, langCode) => {
    try {
      const currentHidden = book.hiddenLanguages || [];
      const updatedHidden = currentHidden.includes(langCode)
        ? currentHidden.filter(l => l !== langCode)
        : [...currentHidden, langCode];
      
      await setBookLanguageVisibility(book.id, langCode, !updatedHidden.includes(langCode));
      
      // Update local state
      setBooks(prevBooks => prevBooks.map(b => 
        b.id === book.id ? { ...b, hiddenLanguages: updatedHidden } : b
      ));
    } catch (e) {
      console.error("Error toggling hide language:", e);
      alert("Failed to update hidden status.");
    }
  };

  const handleAddBook = async (e) => {
    e.preventDefault();
    if (!selectedCategories || selectedCategories.length === 0) {
      alert("Please select at least one category.");
      return;
    }
    if (!coverFile && !editingBookId) {
      alert("Please select a cover image.");
      return;
    }
    
    setIsSubmitting(true);
    try {
      // 1. Upload Cover Image (if selected)
      let coverUrl = '';
      if (coverFile) {
        coverUrl = await uploadFile(coverFile, `covers/${Date.now()}_${coverFile.name}`);
      }
      
      // 2. Upload Audio for each chapter and calculate total duration
      let totalDuration = 0;
      const processedChapters = [];

      for (let i = 0; i < chapters.length; i++) {
        const chap = chapters[i];
        let audioRemoteUrl = chap.audioUrl || ''; // Use existing if any
        
        if (chap.audioFile) {
          audioRemoteUrl = await uploadFile(chap.audioFile, `audio/chapter_${Date.now()}_${chap.audioFile.name}`);
        }
        
        totalDuration += chap.duration;

        processedChapters.push({
          title: chap.title,
          content: chap.content,
          audioUrl: audioRemoteUrl,
          duration: chap.duration
        });
      }

      // 3. Construct Firestore Book Object
      let bookData = {};
      if (editingBookId) {
        // Use dot notation for updates to avoid overwriting other language maps
        bookData = {
          [`title.${lang}`]: title,
          [`author.${lang}`]: author,
          [`description.${lang}`]: description,
          categories: selectedCategories,
          categoryIds: selectedCategories,
          category: selectedCategories[0] || 'cat-productivity',
          duration: totalDuration, 
          [`chapterSummaries.${lang}`]: processedChapters,
          isPremium: isPremium,
          isDownloadable: isDownloadable,
          isPublished: isPublished,
          updatedAt: new Date().toISOString()
        };
        
        if (coverUrl) {
          const currentBook = books.find(b => b.id === editingBookId);
          if (currentBook && typeof currentBook.coverImageUrl === 'string') {
            // Convert existing string cover to map to migrate to new schema
            const newCoverMap = { [lang]: coverUrl };
            if (lang !== 'en' && currentBook.coverImageUrl) {
              newCoverMap['en'] = currentBook.coverImageUrl;
            }
            bookData.coverImageUrl = newCoverMap;
          } else {
            // Already a map or doesn't exist, update language specific key
            bookData[`coverImageUrl.${lang}`] = coverUrl;
          }
        }
      } else {
        // Use full object structure for new books
        bookData = {
          title: { [lang]: title },
          author: { [lang]: author },
          description: { [lang]: description },
          categories: selectedCategories,
          categoryIds: selectedCategories,
          category: selectedCategories[0] || 'cat-productivity',
          duration: totalDuration, 
          chapterSummaries: { [lang]: processedChapters },
          isPremium: isPremium,
          isDownloadable: isDownloadable,
          isPublished: isPublished,
          updatedAt: new Date().toISOString()
        };
        
        if (coverUrl) {
          bookData.coverImageUrl = { [lang]: coverUrl };
        }
      }
      
      if (editingBookId) {
        await updateBook(editingBookId, bookData, lang);
        
        // Save pending AI data for edited book
        for (const [dataLang, aiData] of Object.entries(pendingAiData)) {
          await addQuizData(editingBookId, dataLang, aiData.quizzes);
          await addFlashcardsData(editingBookId, dataLang, aiData.flashcards);
        }
        setPendingAiData({});
      } else {
        bookData.audioUrl = {};
        bookData.tags = [];
        bookData.fiveMinuteSummary = {};
        bookData.fifteenMinuteSummary = {};
        bookData.keyIdeas = {};
        bookData.keyQuotes = {};
        bookData.actionPoints = {};
        bookData.createdAt = new Date().toISOString();
        const newBookId = await addBook(bookData, lang);
        
        // Save pending AI data
        for (const [dataLang, aiData] of Object.entries(pendingAiData)) {
          await addQuizData(newBookId, dataLang, aiData.quizzes);
          await addFlashcardsData(newBookId, dataLang, aiData.flashcards);
        }
        setPendingAiData({});
      }

      setShowModal(false);
      resetForm();
      await loadBooks(); // Refresh table
    } catch (error) {
      console.error("Error saving book:", error);
      alert(`Failed to save book: ${error.message || "Unknown error"}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleGenerateAi = async () => {
    alert("Study materials (quizzes and flashcards) are generated automatically via the backend Gemini content pipeline when processing books.");
  };

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <h1 className="page-title">Content Management</h1>
        <div className="header-actions">
          <input 
            type="text" 
            placeholder="Search books..." 
            className="input-field" 
            style={{ width: '300px' }}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
          <button className="btn-primary" onClick={() => { resetForm(); setShowModal(true); }}>
            <Plus size={18} />
            Add New Book
          </button>
        </div>
      </div>

      {selectedBookIds.length > 0 && (
        <div className="glass-panel" style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '12px 20px',
          marginBottom: '15px',
          background: 'rgba(30, 41, 59, 0.7)',
          border: '1px solid rgba(255, 255, 255, 0.1)',
          borderRadius: '8px',
          boxShadow: '0 4px 30px rgba(0, 0, 0, 0.1)',
          backdropFilter: 'blur(10px)'
        }}>
          <div style={{ color: '#fff', fontWeight: 'bold' }}>
            {selectedBookIds.length} book{selectedBookIds.length > 1 ? 's' : ''} selected
          </div>
          <div style={{ display: 'flex', gap: '10px' }}>
            <button 
              className="btn-primary" 
              onClick={() => handleBatchPublish(true)}
              style={{ background: '#10B981', border: 'none', padding: '8px 16px', display: 'flex', alignItems: 'center', gap: '6px' }}
            >
              Publish Selected
            </button>
            <button 
              className="btn-primary" 
              onClick={() => handleBatchPublish(false)}
              style={{ background: '#64748B', border: 'none', padding: '8px 16px', display: 'flex', alignItems: 'center', gap: '6px' }}
            >
              Unpublish Selected
            </button>
          </div>
        </div>
      )}

      <div className="glass-panel table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th style={{ width: '40px', textAlign: 'center' }}>
                <input 
                  type="checkbox" 
                  checked={sortedBooks.length > 0 && selectedBookIds.length === sortedBooks.length}
                  onChange={(e) => {
                    if (e.target.checked) {
                      setSelectedBookIds(sortedBooks.map(b => b.id));
                    } else {
                      setSelectedBookIds([]);
                    }
                  }}
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
              </th>
              <th onClick={() => handleSort('title')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Title
                  {sortField === 'title' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('category')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Category
                  {sortField === 'category' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('isPublished')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Status
                  {sortField === 'isPublished' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('languages')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Available Languages
                  {sortField === 'languages' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('chapters')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Key Points
                  {sortField === 'chapters' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('duration')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Total Duration
                  {sortField === 'duration' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('dateAdded')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Date Added
                  {sortField === 'dateAdded' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th onClick={() => handleSort('dateEdited')} className="sortable">
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  Date Edited
                  {sortField === 'dateEdited' && (sortDirection === 'asc' ? <ArrowUp size={14} /> : <ArrowDown size={14} />)}
                </div>
              </th>
              <th>Hide in Lang</th>
              <th>Access</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan="12" style={{textAlign: 'center', padding: '20px'}}>Loading books...</td></tr>
            ) : sortedBooks.length === 0 ? (
              <tr><td colSpan="12" style={{textAlign: 'center', padding: '20px'}}>No books found matching search criteria. Click "Add New Book" to get started!</td></tr>
            ) : sortedBooks.map((book) => (
              <tr key={book.id}>
                <td style={{ textAlign: 'center' }}>
                  <input 
                    type="checkbox" 
                    checked={selectedBookIds.includes(book.id)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        setSelectedBookIds(prev => [...prev, book.id]);
                      } else {
                        setSelectedBookIds(prev => prev.filter(id => id !== book.id));
                      }
                    }}
                    style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                  />
                </td>
                <td>
                  <span className="font-medium" dir="auto">{book.title?.en || book.title?.ku || book.title?.ar || 'Untitled'}</span>
                </td>
                <td className="text-muted">
                  {(() => {
                    const cats = Array.isArray(book.categories) && book.categories.length > 0
                      ? book.categories
                      : (Array.isArray(book.categoryIds) && book.categoryIds.length > 0
                        ? book.categoryIds
                        : (book.category ? [book.category] : []));
                    return cats.length > 0
                      ? cats.map(id => categoryNames[id] || id).join(', ')
                      : 'Uncategorized';
                  })()}
                </td>
                <td>
                  <span className="badge-plan" style={{
                    background: book.isPublished !== false ? '#10B981' : '#64748B',
                    color: '#fff',
                    padding: '4px 8px',
                    borderRadius: '4px',
                    fontSize: '11px',
                    fontWeight: 'bold',
                    textTransform: 'uppercase'
                  }}>
                    {book.isPublished !== false ? 'Published' : 'Draft'}
                  </span>
                </td>
                <td>
                  <span className="badge-plan free">{Object.keys(book.title || {}).join(', ').toUpperCase() || 'EN'}</span>
                </td>
                <td className="text-muted">{book.chapterSummaries ? Object.values(book.chapterSummaries)[0]?.length || 0 : 0} Key Points</td>
                <td className="text-muted">{book.duration ? Math.round(book.duration / 60) + ' min' : '0 min'}</td>
                <td className="text-muted">{book.createdAt ? new Date(book.createdAt).toLocaleDateString() : 'N/A'}</td>
                <td className="text-muted">{book.updatedAt ? new Date(book.updatedAt).toLocaleDateString() : 'N/A'}</td>
                <td>
                  <div style={{ display: 'flex', gap: '6px' }}>
                    {['en', 'ku', 'ar'].map(langCode => {
                      const isHidden = book.hiddenLanguages?.includes(langCode);
                      return (
                        <button
                          key={langCode}
                          type="button"
                          onClick={() => handleToggleHideLanguage(book, langCode)}
                          className="badge-plan"
                          style={{
                            background: isHidden ? '#EF4444' : 'rgba(255,255,255,0.05)',
                            color: isHidden ? '#fff' : '#94A3B8',
                            border: '1px solid rgba(255,255,255,0.1)',
                            cursor: 'pointer',
                            fontSize: '11px',
                            padding: '4px 8px',
                            borderRadius: '4px',
                            fontWeight: 'bold',
                            textTransform: 'uppercase'
                          }}
                          title={isHidden ? `Unhide in ${langCode.toUpperCase()}` : `Hide in ${langCode.toUpperCase()}`}
                        >
                          {langCode}
                        </button>
                      );
                    })}
                  </div>
                </td>
                <td>
                  <span className={`badge-plan ${book.isPremium ? 'premium' : 'free'}`}>
                    {book.isPremium ? 'Premium' : 'Free'}
                  </span>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button className="icon-btn-small" title="Edit" onClick={() => openEditModal(book)}>
                      <Edit2 size={18} />
                    </button>
                    <button className="icon-btn-small" title="Delete" onClick={() => handleDeleteBook(book.id)} style={{ color: '#EF4444' }}>
                      <Trash2 size={18} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showModal && (
        <div className="modal-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, overflowY: 'auto', padding: '40px 0' }}>
          <div className="modal-content glass-panel" style={{ width: '800px', maxWidth: '90%', padding: '32px', position: 'relative', marginTop: 'auto', marginBottom: 'auto' }}>
            <button 
              onClick={() => { setShowModal(false); resetForm(); }} 
              style={{ position: 'absolute', top: '24px', right: '24px', background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer' }}
            >
              <X size={28} />
            </button>
            <h2 style={{ marginBottom: '24px', fontSize: '24px', fontWeight: 'bold' }}>
              {editingBookId ? 'Edit Book' : 'Add / Generate New Book'}
            </h2>
            
            <form onSubmit={handleAddBook} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
              
              {/* Header Configuration */}
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '20px', background: 'rgba(255,255,255,0.05)', padding: '20px', borderRadius: '12px' }}>
                <div style={{ flex: '1 1 200px', minWidth: '180px' }}>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', color: '#94A3B8' }}>Content Language</label>
                  <select className="input-field" value={lang} onChange={e => handleLanguageChange(e.target.value)} style={{ width: '100%' }}>
                    <option value="en">English (EN)</option>
                    <option value="ku">Kurdish (KU)</option>
                    <option value="ar">Arabic (AR)</option>
                  </select>
                </div>
                <div style={{ flex: '1 1 320px', minWidth: '240px' }}>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', color: '#94A3B8' }}>
                    Categories ({selectedCategories.length} selected)
                  </label>
                  <div style={{
                    display: 'flex',
                    flexWrap: 'wrap',
                    gap: '6px',
                    padding: '8px',
                    background: '#1E293B',
                    borderRadius: '8px',
                    border: '1px solid #334155',
                    maxHeight: '140px',
                    overflowY: 'auto'
                  }}>
                    {Object.entries(categoryNames).map(([id, name]) => {
                      const isSelected = selectedCategories.includes(id);
                      return (
                        <button
                          key={id}
                          type="button"
                          onClick={() => {
                            if (isSelected) {
                              if (selectedCategories.length > 1) {
                                setSelectedCategories(selectedCategories.filter(c => c !== id));
                              }
                            } else {
                              setSelectedCategories(Array.from(new Set([...selectedCategories, id])));
                            }
                          }}
                          style={{
                            background: isSelected ? '#3B82F6' : '#334155',
                            color: '#FFFFFF',
                            border: isSelected ? '1px solid #60A5FA' : '1px solid #475569',
                            borderRadius: '16px',
                            padding: '4px 10px',
                            fontSize: '12px',
                            cursor: 'pointer',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '4px',
                            transition: 'all 0.15s ease'
                          }}
                        >
                          <span>{name}</span>
                          {isSelected && <span style={{ fontSize: '10px', fontWeight: 'bold' }}>✓</span>}
                        </button>
                      );
                    })}
                  </div>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', paddingTop: '16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <input type="checkbox" id="publishedToggle" checked={isPublished} onChange={(e) => setIsPublished(e.target.checked)} style={{ width: '20px', height: '20px' }} />
                    <label htmlFor="publishedToggle" style={{ fontSize: '16px', fontWeight: 'bold', color: isPublished ? '#10B981' : '#fff' }}>Published on App</label>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <input type="checkbox" id="premiumToggle" checked={isPremium} onChange={(e) => setIsPremium(e.target.checked)} style={{ width: '20px', height: '20px' }} />
                    <label htmlFor="premiumToggle" style={{ fontSize: '16px', fontWeight: 'bold', color: isPremium ? '#F59E0B' : '#fff' }}>Premium Content</label>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <input type="checkbox" id="downloadToggle" checked={isDownloadable} onChange={(e) => setIsDownloadable(e.target.checked)} style={{ width: '20px', height: '20px' }} />
                    <label htmlFor="downloadToggle" style={{ fontSize: '16px', fontWeight: 'bold', color: isDownloadable ? '#14B8A6' : '#fff' }}>Allow Downloading</label>
                  </div>
                </div>
              </div>

              {/* Basic Info */}
              <div style={{ display: 'flex', gap: '20px' }}>
                <div style={{ flex: 1 }}>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', color: '#94A3B8' }}>Book Title</label>
                  <input type="text" className="input-field" value={title} onChange={e => setTitle(e.target.value)} required style={{ width: '100%', direction: (lang === 'ku' || lang === 'ar') ? 'rtl' : 'ltr', textAlign: (lang === 'ku' || lang === 'ar') ? 'right' : 'left' }} />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', color: '#94A3B8' }}>Author Name</label>
                  <input type="text" className="input-field" value={author} onChange={e => setAuthor(e.target.value)} required style={{ width: '100%', direction: (lang === 'ku' || lang === 'ar') ? 'rtl' : 'ltr', textAlign: (lang === 'ku' || lang === 'ar') ? 'right' : 'left' }} />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', color: '#94A3B8' }}>Short Description</label>
                <textarea className="input-field" value={description} onChange={e => setDescription(e.target.value)} rows={2} required style={{ width: '100%', resize: 'vertical', direction: (lang === 'ku' || lang === 'ar') ? 'rtl' : 'ltr', textAlign: (lang === 'ku' || lang === 'ar') ? 'right' : 'left' }} />
              </div>

              {/* Cover Upload */}
              <div style={{ background: 'rgba(255,255,255,0.05)', padding: '20px', borderRadius: '12px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px', fontSize: '15px', fontWeight: 'bold', color: '#fff' }}>
                  <UploadCloud size={18} color="#14B8A6" /> Cover Image
                </label>
                <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
                  <input type="file" accept="image/*" onChange={(e) => setCoverFile(e.target.files[0])} style={{ color: '#94A3B8', flex: 1 }} />
                  {existingCoverUrl && !coverFile && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: 'rgba(255,255,255,0.1)', padding: '8px 12px', borderRadius: '8px' }}>
                      <img src={existingCoverUrl} alt="Cover" style={{ height: '40px', borderRadius: '4px' }} />
                      <span style={{ fontSize: '12px', color: '#10B981' }}>✓ Existing Cover Saved</span>
                    </div>
                  )}
                </div>
              </div>

              {/* Text Chapters & Audio Playlist */}
              <div style={{ background: 'rgba(255,255,255,0.05)', padding: '20px', borderRadius: '12px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '15px', fontWeight: 'bold', color: '#fff' }}>
                    <Music size={18} color="#8B5CF6" /> Key Points & Audio Playlist
                  </label>
                  <button type="button" onClick={handleAddChapter} style={{ background: '#8B5CF6', color: '#fff', border: 'none', padding: '6px 12px', borderRadius: '6px', cursor: 'pointer', fontSize: '13px', fontWeight: 'bold' }}>
                    + Add Key Point
                  </button>
                </div>
                
                {chapters.map((chapter, index) => (
                  <div key={index} style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '16px', background: 'rgba(0,0,0,0.3)', borderRadius: '8px', marginBottom: '12px', position: 'relative' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <h4 style={{ margin: 0, color: '#14B8A6', fontSize: '16px', fontWeight: 'bold' }}>
                        {index === 0 ? 'Intro' : `Key Point ${index}`}
                      </h4>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        {index > 0 && (
                          <button 
                            type="button" 
                            onClick={() => handleMoveChapter(index, 'up')} 
                            style={{ background: 'transparent', border: 'none', color: '#94A3B8', cursor: 'pointer', padding: 0 }}
                            title="Move Up"
                          >
                            <ArrowUp size={16} />
                          </button>
                        )}
                        {index < chapters.length - 1 && (
                          <button 
                            type="button" 
                            onClick={() => handleMoveChapter(index, 'down')} 
                            style={{ background: 'transparent', border: 'none', color: '#94A3B8', cursor: 'pointer', padding: 0 }}
                            title="Move Down"
                          >
                            <ArrowDown size={16} />
                          </button>
                        )}
                        {chapters.length > 1 && (
                          <button type="button" onClick={() => removeChapter(index)} style={{ background: 'transparent', border: 'none', color: '#EF4444', cursor: 'pointer', padding: 0 }}>
                            <X size={20} />
                          </button>
                        )}
                      </div>
                    </div>
                    
                    <input 
                      type="text" 
                      className="input-field" 
                      placeholder="Key Point Title" 
                      value={chapter.title} 
                      onChange={e => updateChapter(index, 'title', e.target.value)} 
                      required 
                      style={{ direction: (lang === 'ku' || lang === 'ar') ? 'rtl' : 'ltr', textAlign: (lang === 'ku' || lang === 'ar') ? 'right' : 'left' }}
                    />
                    <textarea 
                      className="input-field" 
                      placeholder="Key Point Text Summary (Optional if strictly audiobook)" 
                      value={chapter.content} 
                      onChange={e => updateChapter(index, 'content', e.target.value)} 
                      rows={3} 
                      style={{ resize: 'vertical', direction: (lang === 'ku' || lang === 'ar') ? 'rtl' : 'ltr', textAlign: (lang === 'ku' || lang === 'ar') ? 'right' : 'left' }} 
                    />
                    
                    <div style={{ marginTop: '8px', padding: '12px', background: 'rgba(245, 158, 11, 0.1)', border: '1px solid rgba(245, 158, 11, 0.2)', borderRadius: '8px' }}>
                      <label style={{ display: 'block', marginBottom: '8px', fontSize: '13px', color: '#F59E0B' }}>Upload Key Point Audio (MP3/M4A)</label>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                        <input type="file" accept="audio/*" onChange={(e) => handleChapterAudioChange(index, e)} style={{ color: '#94A3B8', fontSize: '13px', flex: 1 }} />
                        {chapter.duration > 0 && !chapter.audioFile && chapter.audioUrl && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <span style={{ fontSize: '12px', color: '#10B981', fontWeight: 'bold' }}>✓ Existing Audio ({Math.round(chapter.duration / 60)}m)</span>
                            <audio src={chapter.audioUrl} controls style={{ height: '30px', width: '150px' }} />
                          </div>
                        )}
                        {chapter.duration > 0 && chapter.audioFile && chapter.audioPreviewUrl && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                            <span style={{ fontSize: '12px', color: '#14B8A6' }}>New audio: {Math.round(chapter.duration / 60)} mins</span>
                            <audio src={chapter.audioPreviewUrl} controls style={{ height: '30px', width: '150px' }} />
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* AI Study Materials Section */}
              <div style={{ background: 'rgba(255,255,255,0.05)', padding: '20px', borderRadius: '12px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '15px', fontWeight: 'bold', color: '#fff' }}>
                      <Sparkles size={18} color="#EAB308" /> AI Study Materials ({lang.toUpperCase()})
                    </label>
                    <p style={{ margin: 0, marginTop: '4px', fontSize: '13px', color: '#94A3B8' }}>Automatically generate {lang.toUpperCase()} quizzes and flashcards based on your text content.</p>
                  </div>
                  <button type="button" onClick={handleGenerateAi} disabled={isGeneratingAi || aiDataExists} style={{ background: aiDataExists ? '#334155' : '#EAB308', color: aiDataExists ? '#94A3B8' : '#000', border: 'none', padding: '10px 16px', borderRadius: '8px', cursor: aiDataExists ? 'not-allowed' : 'pointer', fontSize: '14px', fontWeight: 'bold', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    {aiDataExists ? 'Already Generated for ' + lang.toUpperCase() : isGeneratingAi ? 'Generating (Takes ~10s)...' : <><Sparkles size={16} /> Auto-Generate</>}
                  </button>
                </div>
              </div>
              
              <button type="submit" className="btn-primary" disabled={isSubmitting} style={{ marginTop: '16px', padding: '16px', fontSize: '16px', width: '100%', justifyContent: 'center' }}>
                {isSubmitting ? 'Uploading Playlist & Saving to Database...' : 'Save Book & Playlist'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default ContentManagement;
