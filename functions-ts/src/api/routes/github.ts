import express from 'express';
import * as admin from 'firebase-admin';
import axios from 'axios';
import { verifyFirebaseToken, AuthenticatedRequest } from '../middleware/auth';

const router = express.Router();

// GitHub configuration
const OWNER = 'AppLabs-IIITK';
const REPO = 'IIITK-Resources';

// Cache TTL in seconds
const TTL_SECONDS = 60;

interface GitHubFile {
  name: string;
  path: string;
  sha: string;
  size: number;
  url: string;
  html_url: string;
  git_url: string;
  download_url: string | null;
  type: 'file' | 'dir';
  _links: {
    self: string;
    git: string;
    html: string;
  };
}

interface CacheDocument {
  payload: GitHubFile[];
  etag: string;
  cachedAt: number;
}

interface ListFolderRequest {
  path?: string;
}

/**
 * Get GitHub token from .env file
 */
function getGitHubToken(): string {
  const token = process.env.GITHUB_TOKEN;

  if (!token) {
    throw new Error('GITHUB_TOKEN not set in .env file');
  }

  return token;
}

/**
 * Convert path to Firestore-safe document ID
 * e.g., "pyqs/cse/ds" -> "pyqs--cse--ds"
 */
function pathToCacheKey(path: string): string {
  if (!path || path === '' || path === '/') {
    return 'root';
  }
  return path.replace(/\//g, '--');
}

/**
 * GET /github/list
 *
 * List contents of a GitHub folder with caching
 * Query params:
 *   - path: folder path (optional, defaults to root)
 */
router.get('/list', verifyFirebaseToken, async (req: AuthenticatedRequest, res) => {
  try {
    const { path = '' }: ListFolderRequest = req.query;

    console.log(`[GitHub] Listing folder: ${path || '(root)'} for user: ${req.user?.uid}`);

    const cacheKey = pathToCacheKey(path);
    const db = admin.firestore();
    const cacheRef = db.collection('github_cache').doc(cacheKey);

    const now = Math.floor(Date.now() / 1000);
    const cacheSnap = await cacheRef.get();

    // Check if we have cached data
    if (cacheSnap.exists) {
      const cacheData = cacheSnap.data() as CacheDocument;
      const { payload, etag, cachedAt } = cacheData;

      // If cache is fresh (within TTL), return immediately
      if (cachedAt && now - cachedAt < TTL_SECONDS) {
        console.log(`[GitHub] Cache hit (fresh): ${cacheKey}`);
        res.status(200).json({
          data: payload,
          cached: true,
          age: now - cachedAt,
        });
        return;
      }

      // Cache exists but is stale, check with GitHub using ETag
      console.log(`[GitHub] Cache stale, checking with GitHub: ${cacheKey}`);

      try {
        const githubUrl = path
          ? `https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}`
          : `https://api.github.com/repos/${OWNER}/${REPO}/contents`;

        const githubResponse = await axios.get<GitHubFile[]>(githubUrl, {
          headers: {
            'Authorization': `Bearer ${getGitHubToken()}`,
            'Accept': 'application/vnd.github+json',
            'If-None-Match': etag,
          },
          validateStatus: (status: number) => status === 200 || status === 304,
        });

        // 304 Not Modified - cached data is still valid
        if (githubResponse.status === 304) {
          console.log(`[GitHub] GitHub returned 304, cache still valid: ${cacheKey}`);

          // Update cache timestamp (fire-and-forget)
          cacheRef.update({ cachedAt: now }).catch((err) => {
            console.error('[GitHub] Failed to update cache timestamp:', err);
          });

          res.status(200).json({
            data: payload,
            cached: true,
            age: now - cachedAt,
          });
          return;
        }

        // 200 OK - new data from GitHub
        console.log(`[GitHub] GitHub returned new data: ${cacheKey}`);

        const newEtag = githubResponse.headers.etag || '';
        const newPayload = githubResponse.data;

        // Update cache (fire-and-forget)
        cacheRef.set({
          payload: newPayload,
          etag: newEtag,
          cachedAt: now,
        }).catch((err) => {
          console.error('[GitHub] Failed to update cache:', err);
        });

        res.status(200).json({
          data: newPayload,
          cached: false,
          age: 0,
        });
        return;

      } catch (error: any) {
        console.error('[GitHub] Error checking with GitHub:', error.message);

        // If GitHub API fails, return stale cache if available
        if (payload) {
          console.log(`[GitHub] Returning stale cache due to error: ${cacheKey}`);
          res.status(200).json({
            data: payload,
            cached: true,
            stale: true,
            age: now - cachedAt,
          });
          return;
        }

        throw error;
      }
    }

    // No cache exists, fetch from GitHub
    console.log(`[GitHub] No cache, fetching from GitHub: ${cacheKey}`);

    const githubUrl = path
      ? `https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}`
      : `https://api.github.com/repos/${OWNER}/${REPO}/contents`;

    const githubResponse = await axios.get<GitHubFile[]>(githubUrl, {
      headers: {
        'Authorization': `Bearer ${getGitHubToken()}`,
        'Accept': 'application/vnd.github+json',
      },
    });

    const newEtag = githubResponse.headers.etag || '';
    const newPayload = githubResponse.data;

    // Store in cache (fire-and-forget)
    cacheRef.set({
      payload: newPayload,
      etag: newEtag,
      cachedAt: now,
    }).catch((err) => {
      console.error('[GitHub] Failed to create cache:', err);
    });

    res.status(200).json({
      data: newPayload,
      cached: false,
      age: 0,
    });

  } catch (error: any) {
    console.error('[GitHub] Error in listFolder:', error);

    if (error.response?.status === 404) {
      res.status(404).json({
        error: 'Not Found',
        message: 'The requested path does not exist in the repository',
      });
      return;
    }

    if (error.response?.status === 403) {
      res.status(403).json({
        error: 'Forbidden',
        message: 'GitHub API rate limit exceeded or invalid token',
      });
      return;
    }

    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to fetch folder contents',
    });
  }
});

/**
 * GET /github/tree
 *
 * Get entire repository tree in one request
 * Returns all files and folders recursively
 */
router.get('/tree', verifyFirebaseToken, async (req: AuthenticatedRequest, res) => {
  try {
    const token = getGitHubToken();
    const cacheRef = admin.firestore().collection('github_cache').doc('full_tree');

    console.log(`[GitHub] Fetching repository tree for user: ${req.user?.uid}`);

    // Check cache first
    const cacheDoc = await cacheRef.get();
    const cacheData = cacheDoc.data() as CacheDocument | undefined;
    const now = Math.floor(Date.now() / 1000);

    // Prepare headers for GitHub request
    const headers: Record<string, string> = {
      'Accept': 'application/vnd.github.v3+json',
      'Authorization': `Bearer ${token}`,
      'User-Agent': 'IIITK-Events-App',
    };

    // Add If-None-Match header if we have cached ETag
    if (cacheData?.etag) {
      headers['If-None-Match'] = cacheData.etag;
    }

    try {
      // Fetch tree from GitHub API (recursive)
      const response = await axios.get(
        `https://api.github.com/repos/${OWNER}/${REPO}/git/trees/main?recursive=1`,
        { headers, validateStatus: (status) => status === 200 || status === 304 }
      );

      if (response.status === 304 && cacheData) {
        // Not modified, return cached data
        console.log(`[GitHub] Tree not modified, returning cache`);

        // Update cache timestamp
        await cacheRef.update({ cachedAt: now });

        res.status(200).json({
          files: cacheData.payload,
          fromCache: true,
          truncated: false,
        });
        return;
      }

      // Transform tree items to our format
      const files = response.data.tree.map((item: any) => ({
        name: item.path.split('/').pop() || item.path,
        path: item.path,
        sha: item.sha,
        size: item.size || 0,
        type: item.type === 'tree' ? 'dir' : 'file',
      }));

      // Cache the response
      const newEtag = response.headers['etag'] || '';
      await cacheRef.set({
        payload: files,
        etag: newEtag,
        cachedAt: now,
      });

      console.log(`[GitHub] Tree fetched: ${files.length} items`);

      res.status(200).json({
        files,
        fromCache: false,
        truncated: response.data.truncated || false,
      });

    } catch (axiosError: any) {
      // If network error but we have cache, return stale cache
      if (cacheData) {
        console.log(`[GitHub] Network error, returning stale cache`);
        res.status(200).json({
          files: cacheData.payload,
          fromCache: true,
          stale: true,
        });
        return;
      }
      throw axiosError;
    }

  } catch (error: any) {
    console.error('[GitHub] Error fetching tree:', error.response?.data || error.message);

    if (error.response?.status === 404) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Repository not found or tree does not exist',
      });
      return;
    }

    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to fetch repository tree',
    });
  }
});

/**
 * POST /github/refresh
 *
 * Force refresh tree cache from GitHub (for CI/CD)
 * Requires admin token in Authorization header
 */
router.post('/refresh', async (req, res) => {
  try {
    // Verify using GitHub token (sent in Authorization header)
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
