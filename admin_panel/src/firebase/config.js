import { initializeApp } from 'firebase/app';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';
import { getStorage, connectStorageEmulator } from 'firebase/storage';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { getFunctions, connectFunctionsEmulator } from 'firebase/functions';

// TODO: Replace this with your project's Firebase configuration object
const productionConfig = {
  apiKey: "AIzaSyCVCIDRXB53ovMQkAahmCECUuWBXmdtn2Q",
  authDomain: "partwk-bd4ec.firebaseapp.com",
  projectId: "partwk-bd4ec",
  storageBucket: "partwk-bd4ec.firebasestorage.app",
  messagingSenderId: "545483273382",
  appId: "1:545483273382:web:f4f66e84dad787f4bb3067",
  measurementId: "G-944TF54VP1"
};

const isolated = import.meta.env.VITE_PARTWK_EMULATOR === 'true';
if (isolated && !['127.0.0.1', 'localhost'].includes(window.location.hostname)) {
  throw new Error('Isolated admin tests must be served from localhost.');
}
export const firebaseConfig = isolated ? {
  apiKey: 'demo-emulator-key', authDomain: 'demo-partwk-text.test',
  projectId: 'demo-partwk-text', storageBucket: 'demo-partwk-text.appspot.com',
  messagingSenderId: '1234567890', appId: '1:1234567890:web:0123456789abcdef',
} : productionConfig;

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const auth = getAuth(app);
if (isolated) {
  connectAuthEmulator(auth, 'http://127.0.0.1:19099', { disableWarnings: true });
  connectFirestoreEmulator(db, '127.0.0.1', 18080);
  connectStorageEmulator(storage, '127.0.0.1', 19199);
  connectFunctionsEmulator(getFunctions(app), '127.0.0.1', 5001);
}
