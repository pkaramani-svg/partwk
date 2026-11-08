import { collection, getDocs, doc, setDoc, deleteDoc, updateDoc, query, where, getDoc, onSnapshot, writeBatch } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage, firebaseConfig, auth } from '../firebase/config';
import { getAuth, sendPasswordResetEmail as firebaseSendPasswordResetEmail, createUserWithEmailAndPassword } from 'firebase/auth';
import { initializeApp } from 'firebase/app';
import { getFunctions, httpsCallable } from 'firebase/functions';

// User Management
export const fetchUsers = async () => {
  const querySnapshot = await getDocs(collection(db, 'users'));
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

export const subscribeToUsers = (callback) => {
  return onSnapshot(collection(db, 'users'), (snapshot) => {
    const users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    callback(users);
  }, (error) => {
    console.error("Error in real-time users snapshot:", error);
  });
};

export const updateUserStatus = async (userId, data) => {
  const userRef = doc(db, 'users', userId);
  // Entitlements and family relationships are backend-owned. This panel may
  // edit profile/support fields only; it must not fan out browser writes to
  // other accounts or infer a family entitlement from legacy arrays.
  delete data.familyMembers;
  delete data.hasFamilyPremium;
  await updateDoc(userRef, data);
  return;
  
  // 1. Fetch current user document to see previous state for family entitlements
  try {
    const userSnap = await getDoc(userRef);
    if (userSnap.exists()) {
      const prevData = userSnap.data();
      const prevSub = prevData.subscriptionStatus || 'free';
      const prevRole = prevData.role || 'user';
      const prevStatus = prevData.status || 'active';
      const prevFamily = prevData.familyMembers || [];
      
      const newSub = data.subscriptionStatus || prevSub;
      const newRole = data.role || prevRole;
      const newStatus = data.status || prevStatus;
      const newFamily = data.familyMembers || prevFamily;
      
      const prevEligible = (prevSub === 'premium' || prevSub === 'pro' || prevRole === 'admin') && prevStatus !== 'suspended';
      const newEligible = (newSub === 'premium' || newSub === 'pro' || newRole === 'admin') && newStatus !== 'suspended';
      
      const updateMembersPremium = async (emails, hasPremium) => {
        for (const email of emails) {
          if (!email) continue;
          const normalizedEmail = email.trim().toLowerCase();
          try {
            const q = query(collection(db, 'users'), where('email', '==', normalizedEmail));
            const snap = await getDocs(q);
            for (const memberDoc of snap.docs) {
              await updateDoc(doc(db, 'users', memberDoc.id), {
                hasFamilyPremium: hasPremium
              });
            }
          } catch (e) {
            console.error(`Error updating family member ${email} status to ${hasPremium}:`, e);
          }
        }
      };

      if (prevEligible && newEligible) {
        // Find added and removed emails
        const removedEmails = prevFamily.filter(e => !newFamily.includes(e));
        const addedEmails = newFamily.filter(e => !prevFamily.includes(e));
        
        if (removedEmails.length > 0) await updateMembersPremium(removedEmails, false);
        if (addedEmails.length > 0) await updateMembersPremium(addedEmails, true);
      } else if (prevEligible && !newEligible) {
        // All previous family members lose premium
        if (prevFamily.length > 0) await updateMembersPremium(prevFamily, false);
      } else if (!prevEligible && newEligible) {
        // All new family members get premium
        if (newFamily.length > 0) await updateMembersPremium(newFamily, true);
      }
    }
  } catch (e) {
    console.error("Error updating family sharing member permissions:", e);
  }

  await updateDoc(userRef, data);
};

export const deleteUser = async (userId) => {
  const userRef = doc(db, 'users', userId);
  // Do not mutate related accounts in the browser. A backend deletion/migration
  // worker must revoke family state transactionally before destructive action.
  await deleteDoc(userRef);
  return;
  try {
    const userSnap = await getDoc(userRef);
    if (userSnap.exists()) {
      const prevData = userSnap.data();
      const prevFamily = prevData.familyMembers || [];
      const prevSub = prevData.subscriptionStatus || 'free';
      const prevRole = prevData.role || 'user';
      const prevStatus = prevData.status || 'active';
      const prevEligible = (prevSub === 'premium' || prevSub === 'pro' || prevRole === 'admin') && prevStatus !== 'suspended';
      
      if (prevEligible && prevFamily.length > 0) {
        for (const email of prevFamily) {
          if (!email) continue;
          const normalizedEmail = email.trim().toLowerCase();
          try {
            const q = query(collection(db, 'users'), where('email', '==', normalizedEmail));
            const snap = await getDocs(q);
            for (const memberDoc of snap.docs) {
              await updateDoc(doc(db, 'users', memberDoc.id), {
                hasFamilyPremium: false
              });
            }
          } catch (e) {
            console.error(`Error revoking family premium for ${email} on user deletion:`, e);
          }
        }
      }
    }
  } catch (e) {
    console.error("Error processing family sharing cleanup on user deletion:", e);
  }
  await deleteDoc(userRef);
};

export const sendPasswordResetEmail = async (email) => {
  try {
    const fn = httpsCallable(getFunctions(), 'sendCustomPasswordReset');
    const result = await fn({ email });
    return result.data;
  } catch (callableErr) {
    const response = await fetch('https://us-central1-partwk-bd4ec.cloudfunctions.net/sendCustomPasswordReset', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        data: { email }
      })
    });
    if (!response.ok) {
      throw new Error(callableErr.message || 'Failed to send custom password reset email');
    }
  }
};

export const updateUserPasswordDirectly = async (userId, userEmail, newPassword) => {
  try {
    const fn = httpsCallable(getFunctions(), 'adminUpdateUserPassword');
    const result = await fn({ uid: userId, email: userEmail, newPassword });
    return result.data;
  } catch (callableErr) {
    console.warn('httpsCallable attempt failed, falling back to HTTP fetch:', callableErr);
    const token = auth.currentUser ? await auth.currentUser.getIdToken() : null;
    const headers = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch('https://us-central1-partwk-bd4ec.cloudfunctions.net/adminUpdateUserPassword', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        data: { uid: userId, email: userEmail, newPassword }
      })
    });
    if (!response.ok) {
      const errJson = await response.json().catch(() => ({}));
      const message = errJson.error?.message || callableErr.message || 'Server rejected password update. Administrator permissions required.';
      throw new Error(message);
    }
  }
};

export const createNewUserManually = async (userData) => {
  // Use a secondary app instance so we don't sign out the current admin user
  const secondaryApp = initializeApp(firebaseConfig, `SecondaryApp_${Date.now()}`);
  const secondaryAuth = getAuth(secondaryApp);
  
  // Create user in Auth
  const userCredential = await createUserWithEmailAndPassword(secondaryAuth, userData.email, userData.password);
  
  // Create user document in Firestore
  const newUserRef = doc(db, 'users', userCredential.user.uid);
  const firestoreData = {
    email: userData.email,
    name: userData.name,
    role: userData.role || 'user',
    subscriptionStatus: userData.subscriptionStatus || 'free',
    createdAt: new Date().toISOString(),
    completedBooks: [],
    listeningProgress: {},
    streakCount: 0,
    selectedLanguage: 'en'
  };
  if (userData.subscriptionStatus === 'premium') {
    const now = new Date();
    const expiry = new Date();
    expiry.setFullYear(now.getFullYear() + 1);
    firestoreData.subscriptionStartDate = now.toISOString();
    firestoreData.subscriptionExpiryDate = expiry.toISOString();
  }
  await setDoc(newUserRef, firestoreData);
  
  // Clean up secondary app if possible (though auth persists, we can just let it GC)
  return userCredential.user.uid;
};

// Book Management
export const fetchBooks = async () => {
  const [publishedSnap, draftSnap] = await Promise.all([
    getDocs(collection(db, 'books')),
    getDocs(collection(db, 'books_draft'))
  ]);
  
  const publishedBooks = [];
  const misplacedDrafts = [];
  
  publishedSnap.docs.forEach((doc) => {
    const data = doc.data();
    if (data.isPublished === false) {
      misplacedDrafts.push({ id: doc.id, ...data });
    } else {
      publishedBooks.push({ id: doc.id, ...data, isPublished: true });
    }
  });
  
  if (misplacedDrafts.length > 0) {
    const batch = writeBatch(db);
    misplacedDrafts.forEach((book) => {
      const draftRef = doc(db, 'books_draft', book.id);
      const publishedRef = doc(db, 'books', book.id);
      batch.set(draftRef, { ...book, isPublished: false });
      batch.delete(publishedRef);
    });
    await batch.commit();
    
    const updatedDraftSnap = await getDocs(collection(db, 'books_draft'));
    const draftBooks = updatedDraftSnap.docs.map(doc => ({ id: doc.id, ...doc.data(), isPublished: false }));
    return [...publishedBooks, ...draftBooks];
  }
  
  const draftBooks = draftSnap.docs.map(doc => ({ id: doc.id, ...doc.data(), isPublished: false }));
  return [...publishedBooks, ...draftBooks];
};

export const getBookForEditing = async (bookId) => {
  const result = await httpsCallable(getFunctions(), 'getBookForEditing')({ bookId });
  return { id: bookId, ...result.data.book };
};

const publishBookLanguage = async (bookId, language) => {
  await httpsCallable(getFunctions(), 'publishBookLanguage')({ bookId, language });
};

export const setBookLanguageVisibility = async (bookId, language, visible) => {
  await httpsCallable(getFunctions(), 'setBookLanguageVisibility')({ bookId, language, visible });
};

export const addBook = async (bookData, language) => {
  const isPub = bookData.isPublished !== false;
  if (isPub && language) {
    const draft = doc(collection(db, 'books_draft'));
    await setDoc(draft, { ...bookData, isPublished: false });
    await publishBookLanguage(draft.id, language);
    return draft.id;
  }
  if (isPub && bookData.isPremium === true) throw new Error('Select a language to publish securely.');
  const collectionName = isPub ? 'books' : 'books_draft';
  const newBookRef = doc(collection(db, collectionName));
  await setDoc(newBookRef, bookData);
  return newBookRef.id;
};

export const updateBook = async (bookId, bookData, language) => {
  const publishedRef = doc(db, 'books', bookId);
  const draftRef = doc(db, 'books_draft', bookId);
  
  const publishedSnap = await getDoc(publishedRef);
  const existsInPublished = publishedSnap.exists();
  
  const currentDocSnap = existsInPublished ? publishedSnap : await getDoc(draftRef);
  if (!currentDocSnap.exists()) {
    throw new Error("Book not found in any collection.");
  }
  
  const currentData = language ? await getBookForEditing(bookId) : currentDocSnap.data();
  delete currentData.id;
  let targetIsPublished = currentData.isPublished !== false;
  
  const mergedData = { ...currentData };
  Object.keys(bookData).forEach((key) => {
    if (key.includes('.')) {
      const parts = key.split('.');
      if (parts.length === 2) {
        const [parent, child] = parts;
        mergedData[parent] = {
          ...(mergedData[parent] || {}),
          [child]: bookData[key]
        };
      }
    } else {
      mergedData[key] = bookData[key];
    }
  });
  
  if (bookData.isPublished !== undefined) {
    targetIsPublished = bookData.isPublished;
    mergedData.isPublished = targetIsPublished;
  }

  if (targetIsPublished && language) {
    await setDoc(draftRef, { ...mergedData, isPublished: false });
    await publishBookLanguage(bookId, language);
    return;
  }

  if (targetIsPublished && mergedData.isPremium === true) {
    throw new Error('Premium publishing is unavailable until secure publishing is configured. Save this book as a draft.');
  }
  
  if (existsInPublished && !targetIsPublished) {
    await setDoc(draftRef, mergedData);
    await deleteDoc(publishedRef);
  } else if (!existsInPublished && targetIsPublished) {
    await setDoc(publishedRef, mergedData);
    await deleteDoc(draftRef);
  } else {
    const targetRef = targetIsPublished ? publishedRef : draftRef;
    await setDoc(targetRef, mergedData);
  }
};

export const deleteBook = async (bookId) => {
  await Promise.all([
    deleteDoc(doc(db, 'books', bookId)),
    deleteDoc(doc(db, 'books_draft', bookId))
  ]);
};

export const publishBooksBatch = async (bookIds, publishState = true) => {
  if (publishState) {
    throw new Error('Publish each book from its editor after selecting the language to publish.');
  }
  throw new Error('Bulk unpublishing is temporarily unavailable to avoid replacing saved drafts.');
};

export const addQuizData = async (bookId, langCode, quizzesArray) => {
  const quizRef = doc(db, 'quizzes_draft', `quiz_${bookId}_${langCode}`);
  await setDoc(quizRef, {
    id: `quiz_${bookId}_${langCode}`,
    bookId: bookId,
    langCode: langCode,
    questions: quizzesArray
  });
};

export const addFlashcardsData = async (bookId, langCode, flashcardsArray) => {
  // Save each flashcard to the flashcards collection
  for (const fc of flashcardsArray) {
    const fcRef = doc(collection(db, 'flashcards_draft'));
    await setDoc(fcRef, {
      ...fc,
      bookId: bookId,
      langCode: langCode
    });
  }
};

export const checkAiDataExists = async (bookId, langCode) => {
  const [draft, published] = await Promise.all(['quizzes_draft', 'quizzes'].map(name =>
    getDocs(query(collection(db, name), where('bookId', '==', bookId), where('langCode', '==', langCode)))));
  return !draft.empty || !published.empty;
};

// Storage Management
export const uploadFile = async (file, path) => {
  const storageRef = ref(storage, path);
  const snapshot = await uploadBytes(storageRef, file);
  const downloadUrl = await getDownloadURL(snapshot.ref);
  return downloadUrl;
};

// Global Settings
export const fetchGlobalSettings = async () => {
  const settingsRef = doc(db, 'settings', 'global');
  const docSnap = await getDocs(collection(db, 'settings'));
  const data = docSnap.docs.find(d => d.id === 'global');
  return data ? data.data() : null;
};

export const saveGlobalSettings = async (settingsData) => {
  const settingsRef = doc(db, 'settings', 'global');
  await setDoc(settingsRef, settingsData, { merge: true });
};

// Popup Management
export const fetchPopups = async () => {
  const querySnapshot = await getDocs(collection(db, 'popups'));
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

export const addPopup = async (popupData) => {
  const newRef = doc(collection(db, 'popups'));
  const id = newRef.id;
  const data = {
    ...popupData,
    id,
    analytics: popupData.analytics || { seen: 0, clicked: 0, dismissed: 0, conversion: 0 },
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  await setDoc(newRef, data);
  return id;
};

export const updatePopup = async (popupId, popupData) => {
  const popupRef = doc(db, 'popups', popupId);
  const data = {
    ...popupData,
    updatedAt: new Date().toISOString()
  };
  await updateDoc(popupRef, data);
};

export const deletePopup = async (popupId) => {
  await deleteDoc(doc(db, 'popups', popupId));
};

// Audit Logging
export const fetchAuditLogs = async () => {
  const querySnapshot = await getDocs(collection(db, 'audit_logs'));
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

export const writeAuditLog = async (action, details) => {
  const adminEmail = auth.currentUser?.email || 'unknown_admin';
  const newRef = doc(collection(db, 'audit_logs'));
  await setDoc(newRef, {
    id: newRef.id,
    adminEmail,
    action,
    details,
    timestamp: new Date().toISOString()
  });
};

