/**
 * ExpensePulse — Plaintext Password Remediation Script
 * 
 * PURPOSE:
 * Safely removes the legacy "password" field from any existing Firestore documents
 * at `users/{docId}/profile/info` WITHOUT deleting the user document, the user's
 * transactions, or affecting their Firebase Authentication account.
 * 
 * SAFETY MEASURES:
 * 1. DRY_RUN is enabled by default. Set DRY_RUN = false only after review.
 * 2. Sensitive values are NEVER logged, exported, or displayed.
 * 3. Uses FieldValue.delete() so all other fields (email, uid, profile data) are untouched.
 * 4. Does NOT execute automatically. Requires explicit execution approval.
 * 
 * USAGE:
 * node scripts/cleanup_plaintext_passwords.js
 */

const admin = require('firebase-admin');

// Flag: Change to false only when ready to perform live purge
const DRY_RUN = true;

// Initialize Firebase Admin (Uses Application Default Credentials or service account)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function runPasswordCleanup() {
  console.log(`\n======================================================`);
  console.log(` ExpensePulse — Plaintext Password Remediation`);
  console.log(` Mode: ${DRY_RUN ? 'DRY RUN (Simulated, no data will change)' : 'LIVE REMEDIATION'}`);
  console.log(`======================================================\n`);

  try {
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} user root document(s) to inspect.`);

    let inspectedCount = 0;
    let vulnerableCount = 0;
    let remediatedCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      inspectedCount++;
      const profileInfoRef = userDoc.ref.collection('profile').doc('info');
      const profileDoc = await profileInfoRef.get();

      if (profileDoc.exists) {
        const data = profileDoc.data();
        if (data && 'password' in data) {
          vulnerableCount++;
          console.log(`[!] User document ${userDoc.id}: Plaintext password field detected.`);

          if (!DRY_RUN) {
            await profileInfoRef.update({
              password: admin.firestore.FieldValue.delete()
            });
            remediatedCount++;
            console.log(`    [✓] Successfully removed password field from ${userDoc.id}/profile/info.`);
          }
        }
      }
    }

    console.log(`\n------------------------------------------------------`);
    console.log(` Remediation Summary:`);
    console.log(` Total users inspected   : ${inspectedCount}`);
    console.log(` Documents with password : ${vulnerableCount}`);
    if (DRY_RUN) {
      console.log(` Status                  : DRY RUN complete. 0 records were modified.`);
      console.log(` To execute live purge, set DRY_RUN = false in this script after approval.`);
    } else {
      console.log(` Total purged            : ${remediatedCount}`);
      console.log(` Status                  : ALL plaintext passwords successfully removed!`);
    }
    console.log(`------------------------------------------------------\n`);
  } catch (err) {
    console.error('Error executing remediation script:', err.message);
  }
}

// Only run if executed directly
if (require.main === module) {
  runPasswordCleanup();
}

module.exports = { runPasswordCleanup };
