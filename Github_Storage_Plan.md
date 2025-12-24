# **IIIT Kottayam Resources – GitHub Storage Architecture Plan**

*Using GitHub as storage for PDFs & PPTs (PYQs & Slides) accessed via a Flutter app.*

- **GitHub** → file storage for PDFs, PPTs, notes, PYQs

---

## **📌 Overview**

This project uses:

- **GitHub Actions (CI/CD)** → auto-updates Firestore on every push
- **Firestore** → single source of truth for repository tree
- **Flutter App** → real-time Firestore stream, GitHub-like UI
- **Cloud Functions** → `/refresh` endpoint for manual updates

This ensures:

- **Zero client-side API calls** → Direct Firestore streaming
- **Real-time updates** → CI/CD updates Firestore on every push
- **No rate limits** → GitHub API called only by CI/CD
- **Secure** → Token stored only in Cloud Functions + GitHub secrets
- **Instant** → Firestore stream, no HTTP overhead
- **Scalable** → Firestore handles all users
- **Simple** → 33 lines of service code

---

# **1. GitHub Repository Structure**

Create a GitHub repo like:

```
iiitk-resources/
│
├── pyqs/
│   ├── cse/
│   │   ├── ds/
│   │   │   ├── midsem-2021.pdf
│   │   │   ├── endsem-2022.pdf
│   │   │   └── etc...
│   │   ├── algo/
│   │   └── os/
│   ├── ece/
│   └── mech/
│
└── slides/
    ├── sem3/
    │   ├── cs201/
    │   │   ├── week1/
    │   │   │   ├── lec1.pdf
    │   │   │   └── lec2.pptx
    │   │   ├── week2/
    │   │   └── ...
    └── sem4/
 -- cabins

```

### **Guidelines**

- Organize files by *department → course → week*.
- Always upload both `.pdf` and `.pptx` if needed.
- Keep file names clean and readable.

---

# **2. GitHub Token Setup (Read-Only Access)**

You need a **Fine-Grained Personal Access Token** with:

- **Repository access** → Only your `iiitk-resources` repo
- **Permissions** → `Contents: Read-only`

### Steps

1. Visit:
https://github.com/settings/tokens?type=beta
2. Create new fine-grained token
3. Select *only* your repo
4. Grant read-only permission
5. Copy the token
6. Store it in Firebase:

```bash
firebase functions:config:set github.token="YOUR_TOKEN"

```

**Never store the token in Flutter.**

---

# **3. Architecture: CI/CD + Firestore Streaming**

## **3.1 GitHub Actions Workflow**

Automatically updates Firestore on every push:

```yaml
name: Update Firestore Cache

on:
  push:
    branches: [ main ]
  workflow_dispatch:  # Manual trigger

jobs:
  refresh-cache:
    runs-on: ubuntu-latest
    steps:
      - name: Refresh Firestore tree cache
        run: |
          curl -X POST \
            https://YOUR-FUNCTION-URL/api/github/refresh \
            -H "Authorization: Bearer ${{ secrets.CACHE_REFRESH_TOKEN }}"
```

**Token setup:**
- Add `CACHE_REFRESH_TOKEN` secret to repository
- Use same GitHub token as Cloud Functions

## **3.2 Cloud Function `/refresh` Endpoint**

Called by CI/CD to update Firestore:

- **ETag optimization**: Skips update if repo unchanged (manual reruns)
- **Permissions**: Requires GitHub token authentication
- **Updates**: Firestore `github_cache/full_tree` document

---

## **3.3 Firestore Cache Structure**

Collection:

```
github_cache/
   full_tree          ← Tree API cache
   __root__           ← Per-folder caches
   pyqs--cse--ds
   pyqs--cse--os

```

Document fields:

```json
{
  "payload": [ ...github response... ],
  "etag": "abc123etag",
  "cachedAt": "timestamp"
}

```

---

## **3.4 Cloud Function Logic (Summary)**

```
1. Receive `path`
2. Convert path → Firestore document ID
3. Check Firestore:
     - If cached < 60 seconds old → return cached
4. Otherwise:
     - Call GitHub with If-None-Match: <etag>
5. GitHub returns:
     - 304 → use cached data
     - 200 → update Firestore with new payload & etag
6. Return folder listing to Flutter

```

This makes the system extremely efficient and scalable.

---

# **4. Flutter App Architecture**

### **Main Screens**

- **Home Page** → Choose “PYQs” or “Slides”
- **Folder Browser** → GitHub-like UI for navigation
- **File Viewer**
    - PDF viewer (in-app)
    - PPT viewer (system app or pre-converted PDF)

---

## **4.1 Folder Browser Flow**

1. **App opens**: Subscribes to Firestore stream
2. **Real-time data**: Tree updates automatically when CI/CD runs
3. **Filter locally**: Show current folder from cached tree
4. **Zero HTTP calls**: All from Firestore stream

```dart
// Stream from Firestore (real-time!)
final githubTreeProvider = StreamProvider<List<GitHubFile>>((ref) {
  return FirebaseFirestore.instance
      .collection('github_cache')
      .doc('full_tree')
      .snapshots()
      .map((snapshot) => parseFiles(snapshot.data()['payload']));
});
```

**Benefits:**
- Instant updates when files are pushed
- No loading states (stream)
- Works offline (Firestore persistence)
- Breadcrumb navigation

---

## **4.2 File Viewer Flow**

### PDFs

**Package:** `syncfusion_flutter_pdfviewer`

Load directly from GitHub Raw CDN:
```
https://raw.githubusercontent.com/AppLabs-IIITK/IIITK-Resources/main/<path>
```

Features:
- Zoom controls
- Page navigation
- Bookmark view
- Download button

### PPT/PPTX

**Google Docs Viewer** via WebView:
- Uses `webview_flutter`
- URL: `https://docs.google.com/viewer?url=<encoded_file_url>&embedded=true`
- Download button to open in external apps

### Text/Markdown/Code

**In-app text viewer:**
- Syntax highlighting for code files
- Markdown rendering for `.md` files
- Copy button
- Download button

Direct file loading from GitHub Raw CDN for all file types.

---

# 5. **Core Cloud Function (Reference Implementation)**

## `/refresh` Endpoint (Called by CI/CD)

```typescript
import express from 'express';
import * as admin from 'firebase-admin';
import axios from 'axios';

const router = express.Router();
const OWNER = 'AppLabs-IIITK';
const REPO = 'IIITK-Resources';

function getGitHubToken(): string {
  const token = process.env.GITHUB_TOKEN;
  if (!token) throw new Error('GITHUB_TOKEN not set');
  return token;
}

/**
 * POST /github/refresh
 *
 * Updates Firestore cache from GitHub (triggered by CI/CD)
 * Includes ETag optimization to skip unnecessary updates
 */
router.post('/refresh', async (req, res) => {
  try {
    // Verify using GitHub token
    const authHeader = req.headers.authorization;
    const expectedToken = getGitHubToken();

    if (!authHeader || authHeader !== `Bearer ${expectedToken}`) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid GitHub token',
      });
    }

    const token = getGitHubToken();
    const cacheRef = admin.firestore().collection('github_cache').doc('full_tree');

    console.log('[GitHub] Force refreshing tree cache (CI/CD triggered)');

    // Get current cache to check ETag
    const cacheDoc = await cacheRef.get();
    const cacheData = cacheDoc.data();
    const now = Math.floor(Date.now() / 1000);

    const headers: Record<string, string> = {
      'Accept': 'application/vnd.github.v3+json',
      'Authorization': `Bearer ${token}`,
      'User-Agent': 'IIITK-Events-App',
    };

    // Use ETag if available (for manual reruns)
    if (cacheData?.etag) {
      headers['If-None-Match'] = cacheData.etag;
    }

    // Fetch from GitHub with ETag
    const response = await axios.get(
      `https://api.github.com/repos/${OWNER}/${REPO}/git/trees/main?recursive=1`,
      {
        headers,
        validateStatus: (status) => status === 200 || status === 304,
      }
    );

    // 304 Not Modified - repo hasn't changed since last update
    if (response.status === 304 && cacheData) {
      console.log('[GitHub] Repo unchanged (304), skipping update');

      // Just update timestamp
      await cacheRef.update({ cachedAt: now });

      return res.status(200).json({
        success: true,
        message: 'Cache already up-to-date (repo unchanged)',
        itemCount: cacheData.payload?.length || 0,
        skipped: true,
      });
    }

    // Transform tree items
    const files = response.data.tree.map((item: any) => ({
      name: item.path.split('/').pop() || item.path,
      path: item.path,
      sha: item.sha,
      size: item.size || 0,
      type: item.type === 'tree' ? 'dir' : 'file',
    }));

    // Update cache with new data
    const newEtag = response.headers['etag'] || '';
    await cacheRef.set({
      payload: files,
      etag: newEtag,
      cachedAt: now,
    });

    console.log(`[GitHub] Cache refreshed: ${files.length} items`);

    return res.status(200).json({
      success: true,
      message: 'Tree cache refreshed successfully',
      itemCount: files.length,
      truncated: response.data.truncated || false,
    });

  } catch (error: any) {
    console.error('[GitHub] Error refreshing tree:', error.message);

    return res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to refresh tree cache',
    });
  }
});

export { router as githubRouter };
```

**Key Features:**
- ✅ **ETag optimization** - Skips update if repo unchanged (304 response)
- ✅ **Token authentication** - Uses GitHub token for security
- ✅ **Firestore update** - Single document: `github_cache/full_tree`
- ✅ **Error handling** - Returns meaningful error messages
- ✅ **Logging** - Tracks all updates in Cloud Functions logs

## Per-Folder Endpoint (Fallback)

```typescript
/**
 * GET /github/list
 * List contents of a specific folder with caching
 * Query params: path (optional, defaults to root)
 */
router.get('/list', verifyFirebaseToken, async (req: AuthenticatedRequest, res) => {
  try {
    const path = (req.query.path as string) || '';
    console.log(`[GitHub] Listing folder: ${path || '(root)'}`);

    const cacheKey = path.replace(/\//g, '--') || 'root';
    const cacheRef = admin.firestore().collection('github_cache').doc(cacheKey);
    const now = Math.floor(Date.now() / 1000);
    const cacheSnap = await cacheRef.get();

    if (cacheSnap.exists) {
      const cacheData = cacheSnap.data();
      const { payload, etag, cachedAt } = cacheData;

      // Fresh cache (< 60 seconds)
      if (cachedAt && now - cachedAt < 60) {
        return res.status(200).json({
          data: payload,
          cached: true,
          age: now - cachedAt,
        });
      }

      // Check with GitHub using ETag
      const githubUrl = path
        ? `https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}`
        : `https://api.github.com/repos/${OWNER}/${REPO}/contents`;

      try {
        const githubResponse = await axios.get(githubUrl, {
          headers: {
            'Authorization': `Bearer ${getGitHubToken()}`,
            'Accept': 'application/vnd.github+json',
            'If-None-Match': etag,
          },
          validateStatus: (status) => status === 200 || status === 304,
        });

        // 304 Not Modified - use cache
        if (githubResponse.status === 304) {
          await cacheRef.update({ cachedAt: now });
          return res.status(200).json({
            data: payload,
            cached: true,
            age: now - cachedAt,
          });
        }

        // 200 OK - new data
        const newEtag = githubResponse.headers.etag || '';
        await cacheRef.set({
          payload: githubResponse.data,
          etag: newEtag,
          cachedAt: now,
        });

        return res.status(200).json({
          data: githubResponse.data,
          cached: false,
          age: 0,
        });

      } catch (error) {
        // Network error - return stale cache if available
        if (payload) {
          return res.status(200).json({
            data: payload,
            cached: true,
            stale: true,
            age: now - cachedAt,
          });
        }
        throw error;
      }
    }

    // No cache - fetch from GitHub
    const githubUrl = path
      ? `https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}`
      : `https://api.github.com/repos/${OWNER}/${REPO}/contents`;

    const githubResponse = await axios.get(githubUrl, {
      headers: {
        'Authorization': `Bearer ${getGitHubToken()}`,
        'Accept': 'application/vnd.github+json',
      },
    });

    const newEtag = githubResponse.headers.etag || '';
    await cacheRef.set({
      payload: githubResponse.data,
      etag: newEtag,
      cachedAt: now,
    });

    res.status(200).json({
      data: githubResponse.data,
      cached: false,
      age: 0,
    });

  } catch (error: any) {
    console.error('[GitHub] Error in listFolder:', error);

    if (error.response?.status === 404) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'The requested path does not exist',
      });
    }

    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to fetch folder contents',
    });
  }
});
```