const admin = require('firebase-admin');

admin.initializeApp();

async function cleanupOrphans() {
  const db = admin.firestore();
  const auth = admin.auth();
  let pageToken;
  let count = 0;

  try {
    console.log("Fetching all Auth users to cross-check with Firestore...");
    do {
      const listUsersResult = await auth.listUsers(1000, pageToken);
      pageToken = listUsersResult.pageToken;

      for (const userRecord of listUsersResult.users) {
        const docRef = db.collection('users').doc(userRecord.uid);
        const docSnap = await docRef.get();

        if (!docSnap.exists) {
          console.log(`Orphan found! Deleting Auth user: ${userRecord.email} (${userRecord.uid})`);
          await auth.deleteUser(userRecord.uid);
          count++;
        }
      }
    } while (pageToken);

    console.log(`Cleanup complete! Deleted ${count} orphaned Auth records.`);
  } catch (error) {
    console.error("Error during cleanup:", error);
  }
}

cleanupOrphans();
