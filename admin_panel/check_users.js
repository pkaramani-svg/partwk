import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCVCIDRXB53ovMQkAahmCECUuWBXmdtn2Q",
  authDomain: "partwk-bd4ec.firebaseapp.com",
  projectId: "partwk-bd4ec",
  storageBucket: "partwk-bd4ec.firebasestorage.app",
  messagingSenderId: "545483273382",
  appId: "1:545483273382:web:f4f66e84dad787f4bb3067",
  measurementId: "G-944TF54VP1"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function checkUsers() {
  const querySnapshot = await getDocs(collection(db, 'users'));
  console.log(`Found ${querySnapshot.docs.length} users in Firestore.`);
  querySnapshot.docs.forEach(doc => {
    console.log(doc.id, doc.data().email, doc.data().name, doc.data().role);
  });
  process.exit(0);
}

checkUsers();
