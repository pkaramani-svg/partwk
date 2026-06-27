import { initializeApp } from "firebase/app";
import { getFirestore, collection, getDocs } from "firebase/firestore";
import fs from 'fs';

const firebaseConfig = JSON.parse(fs.readFileSync('../firebase.json', 'utf8'));
// wait, firebase.json doesn't contain the config, it contains hosting rules.
