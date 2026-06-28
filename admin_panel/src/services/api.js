import { collection, getDocs, doc, setDoc, deleteDoc, updateDoc, query, where, getDoc, onSnapshot } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage, firebaseConfig } from '../firebase/config';
import { getAuth, sendPasswordResetEmail as firebaseSendPasswordResetEmail, createUserWithEmailAndPassword } from 'firebase/auth';
import { initializeApp } from 'firebase/app';

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
  const response = await fetch('https://us-central1-partwk-bd4ec.cloudfunctions.net/sendCustomPasswordReset', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      data: { email: email }
    })
  });
  
  if (!response.ok) {
    throw new Error('Failed to send custom password reset email');
  }
};

export const updateUserPasswordDirectly = async (userId, userEmail, newPassword) => {
  try {
    const response = await fetch('https://us-central1-partwk-bd4ec.cloudfunctions.net/adminUpdateUserPassword', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        data: { uid: userId, email: userEmail, newPassword: newPassword }
      })
    });
    if (!response.ok) {
      const errJson = await response.json().catch(() => ({}));
      throw new Error(errJson.error?.message || 'Cloud function update failed');
    }
  } catch (e) {
    console.warn("Cloud function fallback: Storing password update request in Firestore user record:", e);
    const userRef = doc(db, 'users', userId);
    await updateDoc(userRef, {
      pendingAdminPassword: newPassword,
      passwordUpdatedAt: new Date().toISOString()
    });
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
  const querySnapshot = await getDocs(collection(db, 'books'));
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

export const addBook = async (bookData) => {
  const newBookRef = doc(collection(db, 'books'));
  await setDoc(newBookRef, bookData);
  return newBookRef.id;
};

export const updateBook = async (bookId, bookData) => {
  const bookRef = doc(db, 'books', bookId);
  await updateDoc(bookRef, bookData);
};

export const deleteBook = async (bookId) => {
  await deleteDoc(doc(db, 'books', bookId));
};

export const addQuizData = async (bookId, langCode, quizzesArray) => {
  const quizRef = doc(db, 'quizzes', `quiz_${bookId}_${langCode}`);
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
    const fcRef = doc(collection(db, 'flashcards'));
    await setDoc(fcRef, {
      ...fc,
      bookId: bookId,
      langCode: langCode
    });
  }
};

export const checkAiDataExists = async (bookId, langCode) => {
  const q = query(collection(db, 'quizzes'), where('bookId', '==', bookId), where('langCode', '==', langCode));
  const snapshot = await getDocs(q);
  return !snapshot.empty;
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
