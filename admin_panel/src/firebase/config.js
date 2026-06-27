import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';
import { getAuth } from 'firebase/auth';

// TODO: Replace this with your project's Firebase configuration object
export const firebaseConfig = {
  apiKey: "AIzaSyCVCIDRXB53ovMQkAahmCECUuWBXmdtn2Q",
  authDomain: "partwk-bd4ec.firebaseapp.com",
  projectId: "partwk-bd4ec",
  storageBucket: "partwk-bd4ec.firebasestorage.app",
  messagingSenderId: "545483273382",
  appId: "1:545483273382:web:f4f66e84dad787f4bb3067",
  measurementId: "G-944TF54VP1"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const auth = getAuth(app);
