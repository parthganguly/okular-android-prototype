package org.kde.something;

import android.content.ContentResolver;
import android.content.ClipData;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.pdf.PdfRenderer;
import android.util.Log;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.ParcelFileDescriptor;
import android.os.StrictMode;
import android.net.Uri;
import android.provider.DocumentsContract;
import android.provider.DocumentsContract.Document;
import android.provider.OpenableColumns;
import android.provider.Settings;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;
import android.widget.Toast;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import org.qtproject.qt.android.bindings.QtActivity;

class FileClass
{
    private static OpenFileActivity currentActivity;

    public static native void openUri(String uri);
    public static native void updateLibrary(String json);
    public static native void closeDocument();

    public static void setActivity(OpenFileActivity activity)
    {
        currentActivity = activity;
    }

    public static void handleViewIntent()
    {
        if (currentActivity == null) {
            Log.w(OpenFileActivity.TAG, "Cannot handle view intent without an activity");
            return;
        }

        currentActivity.handleViewIntent();
    }

    public static String contentUrlToFd(String url)
    {
        if (currentActivity == null) {
            Log.w(OpenFileActivity.TAG, "Cannot convert URI without an activity: " + url);
            return url;
        }

        return currentActivity.contentUrlToFd(url);
    }

    public static String nativeLibraryDir()
    {
        if (currentActivity == null) {
            Log.w(OpenFileActivity.TAG, "Cannot query native library dir without an activity");
            return "";
        }

        return currentActivity.getApplicationInfo().nativeLibraryDir;
    }

    public static void setReaderMode(boolean enabled)
    {
        if (currentActivity == null) {
            Log.w(OpenFileActivity.TAG, "Cannot change reader mode without an activity");
            return;
        }

        currentActivity.setReaderMode(enabled);
    }

    public static int statusBarHeight()
    {
        return currentActivity == null ? 0 : currentActivity.systemBarDimensionDp("status_bar_height");
    }

    public static int navigationBarHeight()
    {
        return currentActivity == null ? 0 : currentActivity.systemBarDimensionDp("navigation_bar_height");
    }

    public static void requestAllFilesAccess()
    {
        if (currentActivity != null) {
            currentActivity.requestAllFilesAccess();
        }
    }

    public static void openLibraryFolder()
    {
        if (currentActivity != null) {
            currentActivity.openLibraryFolder();
        }
    }

    public static void refreshLibrary()
    {
        if (currentActivity != null) {
            currentActivity.publishLibrary();
        }
    }

    public static void openLibraryFolderUri(String uri)
    {
        if (currentActivity != null) {
            currentActivity.openLibraryFolderUri(uri);
        }
    }

    public static void navigateLibraryUp()
    {
        if (currentActivity != null) {
            currentActivity.navigateLibraryUp();
        }
    }

    public static void openLibraryDocument(String uri, String mimeType)
    {
        if (currentActivity != null) {
            currentActivity.openLibraryDocument(uri, mimeType);
        }
    }

    public static void shareCurrentDocument()
    {
        if (currentActivity != null) {
            currentActivity.shareCurrentDocument();
        }
    }

    public static boolean deleteCurrentDocument()
    {
        return currentActivity != null && currentActivity.deleteCurrentDocument();
    }

    public static void clearCurrentDocument()
    {
        if (currentActivity != null) {
            currentActivity.clearCurrentDocument();
        }
    }
}

public class OpenFileActivity extends QtActivity
{
    private static class FolderSummary
    {
        final File folder;
        int count = 0;
        int documentCount = 0;
        int bookCount = 0;
        int pictureCount = 0;
        int newCount = 0;
        int newDocumentCount = 0;
        int newBookCount = 0;
        int newPictureCount = 0;
        long modified = 0;

        FolderSummary(File folder)
        {
            this.folder = folder;
        }

        void add(File file, String category, boolean isNew)
        {
            count++;
            if (CATEGORY_DOCUMENTS.equals(category)) {
                documentCount++;
                if (isNew) {
                    newDocumentCount++;
                }
            } else if (CATEGORY_BOOKS.equals(category)) {
                bookCount++;
                if (isNew) {
                    newBookCount++;
                }
            } else if (CATEGORY_PICTURES.equals(category)) {
                pictureCount++;
                if (isNew) {
                    newPictureCount++;
                }
            }
            if (isNew) {
                newCount++;
            }
            modified = Math.max(modified, file.lastModified());
        }

        int countForCategory(String category)
        {
            if (CATEGORY_DOCUMENTS.equals(category)) {
                return documentCount;
            }
            if (CATEGORY_BOOKS.equals(category)) {
                return bookCount;
            }
            if (CATEGORY_PICTURES.equals(category)) {
                return pictureCount;
            }
            return count;
        }

        int newCountForCategory(String category)
        {
            if (CATEGORY_DOCUMENTS.equals(category)) {
                return newDocumentCount;
            }
            if (CATEGORY_BOOKS.equals(category)) {
                return newBookCount;
            }
            if (CATEGORY_PICTURES.equals(category)) {
                return newPictureCount;
            }
            return newCount;
        }
    }

    static final String TAG = "Okular";
    private static final String OKULAR_MIME_TYPE_QUERY_ITEM = "okularMimeType";
    private static final String OKULAR_FILE_NAME_QUERY_ITEM = "okularFileName";
    private static final int REQUEST_LIBRARY_FOLDER = 3401;
    private static final String LIBRARY_PREFS = "okular_library";
    private static final String PREF_TREE_URI = "treeUri";
    private static final String PREF_STACK = "folderStack";
    private static final String PREF_SCAN_FOLDER_PATH = "scanFolderPath";
    private static final String PREF_LIBRARY_OVERVIEW_CACHE_JSON = "libraryOverviewCacheJson";
    private static final String PREF_LIBRARY_OVERVIEW_CACHE_TIME = "libraryOverviewCacheTime";
    private static final String PREF_RECENT_JSON = "recentJson";
    private static final int MAX_RECENT_DOCUMENTS = 12;
    private static final int MAX_RECENT_THUMBNAIL_WIDTH = 320;
    private static final int MAX_RECENT_THUMBNAIL_HEIGHT = 480;
    private static final long NEW_FILE_WINDOW_MS = 7L * 24L * 60L * 60L * 1000L;
    private static final String CATEGORY_LOCAL = "local";
    private static final String CATEGORY_DOCUMENTS = "documents";
    private static final String CATEGORY_BOOKS = "books";
    private static final String CATEGORY_PICTURES = "pictures";
    private boolean readerModeEnabled = false;
    private int libraryScanGeneration = 0;
    private Uri currentDocumentUri;
    private String currentDocumentMimeType = "";
    private String currentDocumentName = "";
    private OnBackInvokedCallback readerBackCallback;
    private boolean readerBackCallbackRegistered = false;

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        FileClass.setActivity(this);
        prepareFullscreenWindowForQt();
        super.onCreate(savedInstanceState);
        FileClass.setActivity(this);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            readerBackCallback = () -> handleBackRequest();
            try {
                getOnBackInvokedDispatcher().registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_OVERLAY, readerBackCallback);
                Log.v(TAG, "Registered overlay Android back callback");
            } catch (RuntimeException e) {
                Log.w(TAG, "Cannot register overlay back callback; falling back to default", e);
                getOnBackInvokedDispatcher().registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, readerBackCallback);
            }
            readerBackCallbackRegistered = true;
        }
        applyReaderMode();
    }

    private void prepareFullscreenWindowForQt()
    {
        final Window window = getWindow();
        if (window == null) {
            return;
        }

        final View decorView = window.getDecorView();
        if (decorView != null) {
            decorView.setBackgroundColor(Color.BLACK);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.setStatusBarColor(Color.BLACK);
            window.setNavigationBarColor(Color.TRANSPARENT);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            final WindowManager.LayoutParams attributes = window.getAttributes();
            attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(attributes);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false);
        } else if (decorView != null) {
            decorView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        }
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event)
    {
        if (event != null && event.getKeyCode() == KeyEvent.KEYCODE_BACK && hasActiveReaderDocument()) {
            if (event.getAction() == KeyEvent.ACTION_UP) {
                Log.v(TAG, "Back key event requested document close");
                FileClass.closeDocument();
            }
            return true;
        }

        return super.dispatchKeyEvent(event);
    }

    @Override
    public void onBackPressed()
    {
        Log.v(TAG, "onBackPressed; readerModeEnabled=" + readerModeEnabled + ", hasDocument=" + (currentDocumentUri != null));
        if (hasActiveReaderDocument()) {
            FileClass.closeDocument();
            return;
        }

        super.onBackPressed();
    }

    @Override
    protected void onDestroy()
    {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && readerBackCallbackRegistered && readerBackCallback != null) {
            getOnBackInvokedDispatcher().unregisterOnBackInvokedCallback(readerBackCallback);
            readerBackCallbackRegistered = false;
        }
        super.onDestroy();
    }

    private SharedPreferences libraryPrefs()
    {
        return getSharedPreferences(LIBRARY_PREFS, MODE_PRIVATE);
    }

    private boolean hasAllFilesAccess()
    {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return Environment.isExternalStorageManager();
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true;
        }

        return checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                || checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
    }

    public void requestAllFilesAccess()
    {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            publishLibrary();
            return;
        }

        try {
            final Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
            intent.setData(Uri.parse("package:" + getPackageName()));
            startActivity(intent);
        } catch (Exception e) {
            Log.w(TAG, "Cannot open per-app all files settings; opening generic page", e);
            startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
        }
    }

    public void openLibraryFolder()
    {
        final Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
        startActivityForResult(intent, REQUEST_LIBRARY_FOLDER);
    }

    public void openLibraryFolderUri(String uri)
    {
        if (uri == null || uri.isEmpty()) {
            return;
        }

        if (hasAllFilesAccess() && uri.startsWith("file:")) {
            final File folder = new File(Uri.parse(uri).getPath());
            libraryPrefs().edit()
                    .putString(PREF_SCAN_FOLDER_PATH, folder.getAbsolutePath())
                    .apply();
            publishLibrary();
            return;
        }

        final ArrayList<String> stack = libraryStack();
        stack.add(uri);
        saveLibraryStack(stack);
        publishLibrary();
    }

    public void navigateLibraryUp()
    {
        if (hasAllFilesAccess() && !libraryPrefs().getString(PREF_SCAN_FOLDER_PATH, "").isEmpty()) {
            libraryPrefs().edit()
                    .remove(PREF_SCAN_FOLDER_PATH)
                    .apply();
            publishLibrary();
            return;
        }

        final ArrayList<String> stack = libraryStack();
        if (stack.size() <= 1) {
            return;
        }

        stack.remove(stack.size() - 1);
        saveLibraryStack(stack);
        publishLibrary();
    }

    public void openLibraryDocument(String uri, String mimeType)
    {
        if (uri == null || uri.isEmpty()) {
            return;
        }

        displayUri(Uri.parse(uri), mimeType);
    }

    public void shareCurrentDocument()
    {
        if (currentDocumentUri == null) {
            Toast.makeText(this, "No open document to share", Toast.LENGTH_SHORT).show();
            return;
        }

        final Uri shareUri = currentDocumentUri;
        final String mimeType = currentDocumentMimeType == null || currentDocumentMimeType.isEmpty() ? "*/*" : currentDocumentMimeType;
        final String title = currentDocumentName == null || currentDocumentName.isEmpty() ? "Okular document" : currentDocumentName;
        final Intent intent = new Intent(Intent.ACTION_SEND);
        intent.setType(mimeType);
        intent.putExtra(Intent.EXTRA_STREAM, shareUri);
        intent.putExtra(Intent.EXTRA_TITLE, title);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.setClipData(ClipData.newUri(getContentResolver(), title, shareUri));

        try {
            // FileProvider is a better long-term path; this keeps file:// library entries shareable in the prototype.
            if ("file".equals(shareUri.getScheme()) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                StrictMode.setVmPolicy(new StrictMode.VmPolicy.Builder().build());
            }
            startActivity(Intent.createChooser(intent, "Share document"));
        } catch (Exception e) {
            Log.w(TAG, "Cannot share current document", e);
            Toast.makeText(this, "Could not share this document", Toast.LENGTH_SHORT).show();
        }
    }

    public boolean deleteCurrentDocument()
    {
        if (currentDocumentUri == null) {
            Toast.makeText(this, "No open document to delete", Toast.LENGTH_SHORT).show();
            return false;
        }

        final Uri deleteUri = currentDocumentUri;
        boolean deleted = false;
        try {
            if ("file".equals(deleteUri.getScheme())) {
                final File file = new File(deleteUri.getPath());
                deleted = file.isFile() && file.delete();
            } else if (!"fd".equals(deleteUri.getScheme())) {
                deleted = DocumentsContract.deleteDocument(getContentResolver(), deleteUri);
            }
        } catch (Exception e) {
            Log.w(TAG, "Cannot delete current document", e);
        }

        if (!deleted) {
            Toast.makeText(this, "Could not delete this document", Toast.LENGTH_SHORT).show();
            return false;
        }

        removeRecentDocument(deleteUri.toString());
        currentDocumentUri = null;
        currentDocumentMimeType = "";
        currentDocumentName = "";
        publishLibrary();
        Toast.makeText(this, "Document deleted", Toast.LENGTH_SHORT).show();
        return true;
    }

    public void clearCurrentDocument()
    {
        currentDocumentUri = null;
        currentDocumentMimeType = "";
        currentDocumentName = "";
        readerModeEnabled = false;
        applyReaderMode();
    }

    private ArrayList<String> libraryStack()
    {
        final ArrayList<String> stack = new ArrayList<>();
        final String encoded = libraryPrefs().getString(PREF_STACK, "");
        if (encoded != null && !encoded.isEmpty()) {
            final String[] parts = encoded.split("\\n");
            for (String part : parts) {
                if (part != null && !part.isEmpty()) {
                    stack.add(part);
                }
            }
        }

        final String treeUri = libraryPrefs().getString(PREF_TREE_URI, "");
        if (stack.isEmpty() && treeUri != null && !treeUri.isEmpty()) {
            stack.add(treeUri);
        }
        return stack;
    }

    private void saveLibraryStack(ArrayList<String> stack)
    {
        final StringBuilder builder = new StringBuilder();
        for (String item : stack) {
            if (item == null || item.isEmpty()) {
                continue;
            }
            if (builder.length() > 0) {
                builder.append('\n');
            }
            builder.append(item);
        }
        libraryPrefs().edit().putString(PREF_STACK, builder.toString()).apply();
    }

    private String currentLibraryFolderUri()
    {
        final ArrayList<String> stack = libraryStack();
        return stack.isEmpty() ? "" : stack.get(stack.size() - 1);
    }

    private String documentIdForFolder(Uri treeUri, Uri folderUri)
    {
        try {
            final String documentId = DocumentsContract.getDocumentId(folderUri);
            if (documentId != null && !documentId.isEmpty()) {
                return documentId;
            }
        } catch (Exception ignored) {
        }
        return DocumentsContract.getTreeDocumentId(treeUri);
    }

    private boolean isSupportedLibraryDocument(String name, String mimeType)
    {
        if (name != null && name.startsWith(".")) {
            return false;
        }

        if (mimeType != null) {
            switch (mimeType) {
            case "application/pdf":
            case "application/epub+zip":
            case "application/oxps":
            case "application/vnd.ms-xpsdocument":
            case "application/x-cb7":
            case "application/x-cbr":
            case "application/x-cbt":
            case "application/x-cbz":
            case "application/x-dvi":
            case "application/x-fictionbook+xml":
            case "application/x-mobipocket-ebook":
            case "application/x-pdf":
            case "application/x-wwf":
            case "image/vnd.djvu":
            case "image/tiff":
            case "text/markdown":
            case "text/plain":
            case "text/x-markdown":
                return true;
            default:
                if (mimeType.startsWith("image/")) {
                    return true;
                }
            }
        }

        final String lowerName = name == null ? "" : name.toLowerCase(Locale.ROOT);
        final String[] extensions = {
            ".pdf", ".epub", ".xps", ".oxps", ".cb7", ".cbr", ".cbt", ".cbz", ".dvi", ".fb2", ".mobi",
            ".md", ".markdown", ".txt", ".djvu", ".djv", ".tif", ".tiff", ".avif", ".bmp", ".gif",
            ".heif", ".jpeg", ".jpg", ".jp2", ".jxl", ".png", ".webp"
        };
        for (String extension : extensions) {
            if (lowerName.endsWith(extension)) {
                return true;
            }
        }
        return false;
    }

    private String displayNameForDocumentUri(Uri uri)
    {
        try (Cursor cursor = getContentResolver().query(uri, new String[] { Document.COLUMN_DISPLAY_NAME }, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                final int column = cursor.getColumnIndex(Document.COLUMN_DISPLAY_NAME);
                if (column >= 0) {
                    final String name = cursor.getString(column);
                    if (name != null && !name.isEmpty()) {
                        return name;
                    }
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Cannot query folder name", e);
        }
        return "Selected Folder";
    }

    private JSONObject libraryEntry(String kind, String name, String uri, String mimeType, long size, long modified) throws JSONException
    {
        final JSONObject entry = new JSONObject();
        entry.put("kind", kind);
        entry.put("name", name == null ? "" : name);
        entry.put("uri", uri == null ? "" : uri);
        entry.put("mimeType", mimeType == null ? "" : mimeType);
        entry.put("size", size);
        entry.put("modified", modified);
        entry.put("isNew", isNewModified(modified));
        return entry;
    }

    private boolean isNewModified(long modified)
    {
        if (modified <= 0) {
            return false;
        }

        final long now = System.currentTimeMillis();
        return modified <= now + 60L * 60L * 1000L && modified >= now - NEW_FILE_WINDOW_MS;
    }

    private JSONArray recentDocumentsJson()
    {
        final String rawJson = libraryPrefs().getString(PREF_RECENT_JSON, "[]");
        try {
            return new JSONArray(rawJson);
        } catch (JSONException e) {
            Log.w(TAG, "Cannot parse recent documents", e);
            return new JSONArray();
        }
    }

    private void removeRecentDocument(String uriString)
    {
        if (uriString == null || uriString.isEmpty()) {
            return;
        }

        final JSONArray oldRecents = recentDocumentsJson();
        final JSONArray newRecents = new JSONArray();
        for (int i = 0; i < oldRecents.length(); ++i) {
            final JSONObject item = oldRecents.optJSONObject(i);
            if (item == null || uriString.equals(item.optString("uri"))) {
                continue;
            }
            newRecents.put(item);
        }

        libraryPrefs().edit()
                .putString(PREF_RECENT_JSON, newRecents.toString())
                .remove(PREF_LIBRARY_OVERVIEW_CACHE_JSON)
                .apply();
    }

    private long sizeForUri(Uri uri)
    {
        if (uri == null) {
            return 0;
        }
        if ("file".equals(uri.getScheme())) {
            final File file = new File(uri.getPath());
            return file.isFile() ? file.length() : 0;
        }

        try (Cursor cursor = getContentResolver().query(uri, new String[] { OpenableColumns.SIZE }, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                final int column = cursor.getColumnIndex(OpenableColumns.SIZE);
                if (column >= 0) {
                    return cursor.getLong(column);
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Cannot query document size", e);
        }
        return 0;
    }

    private long modifiedForUri(Uri uri)
    {
        if (uri == null) {
            return 0;
        }
        if ("file".equals(uri.getScheme())) {
            final File file = new File(uri.getPath());
            return file.isFile() ? file.lastModified() : 0;
        }

        try (Cursor cursor = getContentResolver().query(uri, new String[] { Document.COLUMN_LAST_MODIFIED }, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                final int column = cursor.getColumnIndex(Document.COLUMN_LAST_MODIFIED);
                if (column >= 0) {
                    return cursor.getLong(column);
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Cannot query modified time", e);
        }
        return 0;
    }

    private ParcelFileDescriptor openThumbnailDescriptor(Uri uri) throws FileNotFoundException
    {
        if ("file".equals(uri.getScheme())) {
            return ParcelFileDescriptor.open(new File(uri.getPath()), ParcelFileDescriptor.MODE_READ_ONLY);
        }
        return getContentResolver().openFileDescriptor(uri, "r");
    }

    private InputStream openThumbnailInputStream(Uri uri) throws FileNotFoundException
    {
        if ("file".equals(uri.getScheme())) {
            return new java.io.FileInputStream(new File(uri.getPath()));
        }
        return getContentResolver().openInputStream(uri);
    }

    private File thumbnailFileFor(String uriString, long modified)
    {
        final File directory = new File(getCacheDir(), "library-thumbnails");
        if (!directory.exists() && !directory.mkdirs()) {
            Log.w(TAG, "Cannot create thumbnail cache");
        }
        final String stableName = Integer.toHexString(uriString.hashCode()) + "-" + Long.toHexString(modified) + ".jpg";
        return new File(directory, stableName);
    }

    private Bitmap scaleBitmapToThumbnail(Bitmap source)
    {
        if (source == null || source.getWidth() <= 0 || source.getHeight() <= 0) {
            return source;
        }

        final float scale = Math.min(
                (float) MAX_RECENT_THUMBNAIL_WIDTH / (float) source.getWidth(),
                (float) MAX_RECENT_THUMBNAIL_HEIGHT / (float) source.getHeight());
        if (scale >= 1.0f) {
            return source;
        }

        final int width = Math.max(1, Math.round(source.getWidth() * scale));
        final int height = Math.max(1, Math.round(source.getHeight() * scale));
        return Bitmap.createScaledBitmap(source, width, height, true);
    }

    private String saveThumbnailBitmap(Bitmap bitmap, String uriString, long modified)
    {
        if (bitmap == null) {
            return "";
        }

        final File thumbnail = thumbnailFileFor(uriString, modified);
        if (thumbnail.isFile()) {
            bitmap.recycle();
            return Uri.fromFile(thumbnail).toString();
        }

        Bitmap outputBitmap = null;
        try {
            outputBitmap = scaleBitmapToThumbnail(bitmap);
            try (FileOutputStream output = new FileOutputStream(thumbnail)) {
                outputBitmap.compress(Bitmap.CompressFormat.JPEG, 86, output);
            }
            return Uri.fromFile(thumbnail).toString();
        } catch (Exception e) {
            Log.w(TAG, "Cannot save recent thumbnail", e);
            return "";
        } finally {
            if (outputBitmap != null && outputBitmap != bitmap) {
                outputBitmap.recycle();
            }
            if (!bitmap.isRecycled()) {
                bitmap.recycle();
            }
        }
    }

    private String renderPdfThumbnail(Uri uri, String uriString, long modified)
    {
        PdfRenderer.Page page = null;
        try (ParcelFileDescriptor descriptor = openThumbnailDescriptor(uri)) {
            if (descriptor == null) {
                return "";
            }
            final PdfRenderer renderer = new PdfRenderer(descriptor);
            try {
                if (renderer.getPageCount() <= 0) {
                    return "";
                }

                page = renderer.openPage(0);
                final int pageWidth = Math.max(1, page.getWidth());
                final int pageHeight = Math.max(1, page.getHeight());
                final int width = MAX_RECENT_THUMBNAIL_WIDTH;
                final int height = Math.max(1, Math.min(MAX_RECENT_THUMBNAIL_HEIGHT, Math.round((float) pageHeight * width / (float) pageWidth)));
                final Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                final Canvas canvas = new Canvas(bitmap);
                canvas.drawColor(Color.WHITE);
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);
                return saveThumbnailBitmap(bitmap, uriString, modified);
            } finally {
                if (page != null) {
                    page.close();
                }
                renderer.close();
            }
        } catch (IOException | RuntimeException e) {
            Log.w(TAG, "Cannot render PDF recent thumbnail", e);
            return "";
        }
    }

    private boolean isZipThumbnailImage(String name)
    {
        final String lowerName = name == null ? "" : name.toLowerCase(Locale.ROOT);
        return lowerName.endsWith(".avif")
                || lowerName.endsWith(".bmp")
                || lowerName.endsWith(".gif")
                || lowerName.endsWith(".jpeg")
                || lowerName.endsWith(".jpg")
                || lowerName.endsWith(".png")
                || lowerName.endsWith(".webp");
    }

    private String extractZipThumbnail(Uri uri, String uriString, long modified)
    {
        try (InputStream input = openThumbnailInputStream(uri);
             ZipInputStream zip = new ZipInputStream(input)) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                if (entry.isDirectory() || !isZipThumbnailImage(entry.getName())) {
                    continue;
                }

                final Bitmap bitmap = BitmapFactory.decodeStream(zip);
                if (bitmap != null) {
                    return saveThumbnailBitmap(bitmap, uriString, modified);
                }
            }
        } catch (IOException | RuntimeException e) {
            Log.w(TAG, "Cannot extract comic recent thumbnail", e);
        }
        return "";
    }

    private String thumbnailUriForRecent(Uri uri, String name, String mimeType, String category, long modified)
    {
        if (uri == null) {
            return "";
        }
        final String uriString = uri.toString();
        if (CATEGORY_PICTURES.equals(category)) {
            return uriString;
        }

        final String lowerName = name == null ? "" : name.toLowerCase(Locale.ROOT);
        if ("application/pdf".equals(mimeType) || lowerName.endsWith(".pdf")) {
            return renderPdfThumbnail(uri, uriString, modified);
        }
        if (lowerName.endsWith(".cbz")) {
            return extractZipThumbnail(uri, uriString, modified);
        }

        return "";
    }

    private void recordRecentDocument(Uri uri, String intentType)
    {
        if (uri == null || "fd".equals(uri.getScheme())) {
            return;
        }

        try {
            final String uriString = uri.toString();
            final String name = displayNameForUri(uri);
            String mimeType = mimeTypeForUri(uri, intentType);
            if (mimeType == null || mimeType.isEmpty()) {
                mimeType = mimeTypeForLibraryName(name);
            }

            final long modified = modifiedForUri(uri);
            final JSONObject recent = libraryEntry("file", name, uriString, mimeType, sizeForUri(uri), modified);
            final String category = categoryForLibraryName(name, mimeType);
            recent.put("category", category);
            recent.put("subtitle", "Recently opened");
            final String thumbnailUri = thumbnailUriForRecent(uri, name, mimeType, category, modified);
            if (thumbnailUri != null && !thumbnailUri.isEmpty()) {
                recent.put("thumbnailUri", thumbnailUri);
            }

            final JSONArray oldRecents = recentDocumentsJson();
            final JSONArray newRecents = new JSONArray();
            newRecents.put(recent);
            for (int i = 0; i < oldRecents.length() && newRecents.length() < MAX_RECENT_DOCUMENTS; ++i) {
                final JSONObject item = oldRecents.optJSONObject(i);
                if (item == null || uriString.equals(item.optString("uri"))) {
                    continue;
                }
                newRecents.put(item);
            }

            libraryPrefs().edit()
                    .putString(PREF_RECENT_JSON, newRecents.toString())
                    .remove(PREF_LIBRARY_OVERVIEW_CACHE_JSON)
                    .apply();
        } catch (JSONException e) {
            Log.w(TAG, "Cannot record recent document", e);
        }
    }

    private String documentCountText(int count)
    {
        return count == 1 ? "1 document" : count + " documents";
    }

    private String categoryCountText(String category, int count)
    {
        if (CATEGORY_DOCUMENTS.equals(category)) {
            return count == 1 ? "1 document" : count + " documents";
        }
        if (CATEGORY_BOOKS.equals(category)) {
            return count == 1 ? "1 book" : count + " books";
        }
        if (CATEGORY_PICTURES.equals(category)) {
            return count == 1 ? "1 picture" : count + " pictures";
        }
        return documentCountText(count);
    }

    private boolean endsWithAny(String lowerName, String[] extensions)
    {
        for (String extension : extensions) {
            if (lowerName.endsWith(extension)) {
                return true;
            }
        }
        return false;
    }

    private String categoryForLibraryName(String name, String mimeType)
    {
        final String lowerName = name == null ? "" : name.toLowerCase(Locale.ROOT);
        final String[] bookExtensions = { ".epub", ".fb2", ".mobi", ".cb7", ".cbr", ".cbt", ".cbz" };
        final String[] pictureExtensions = { ".avif", ".bmp", ".gif", ".heif", ".jpeg", ".jpg", ".jp2", ".jxl", ".png", ".webp" };
        if (endsWithAny(lowerName, bookExtensions)) {
            return CATEGORY_BOOKS;
        }
        if (endsWithAny(lowerName, pictureExtensions)) {
            return CATEGORY_PICTURES;
        }
        if (mimeType != null && mimeType.startsWith("image/")
                && !"image/vnd.djvu".equals(mimeType)
                && !"image/tiff".equals(mimeType)) {
            return CATEGORY_PICTURES;
        }
        return CATEGORY_DOCUMENTS;
    }

    private String mimeTypeForLibraryName(String name)
    {
        final String lowerName = name == null ? "" : name.toLowerCase(Locale.ROOT);
        if (lowerName.endsWith(".pdf")) return "application/pdf";
        if (lowerName.endsWith(".epub")) return "application/epub+zip";
        if (lowerName.endsWith(".xps")) return "application/vnd.ms-xpsdocument";
        if (lowerName.endsWith(".oxps")) return "application/oxps";
        if (lowerName.endsWith(".cb7")) return "application/x-cb7";
        if (lowerName.endsWith(".cbr")) return "application/x-cbr";
        if (lowerName.endsWith(".cbt")) return "application/x-cbt";
        if (lowerName.endsWith(".cbz")) return "application/x-cbz";
        if (lowerName.endsWith(".dvi")) return "application/x-dvi";
        if (lowerName.endsWith(".fb2")) return "application/x-fictionbook+xml";
        if (lowerName.endsWith(".mobi")) return "application/x-mobipocket-ebook";
        if (lowerName.endsWith(".md") || lowerName.endsWith(".markdown")) return "text/markdown";
        if (lowerName.endsWith(".txt")) return "text/plain";
        if (lowerName.endsWith(".djvu") || lowerName.endsWith(".djv")) return "image/vnd.djvu";
        if (lowerName.endsWith(".tif") || lowerName.endsWith(".tiff")) return "image/tiff";
        if (lowerName.endsWith(".avif")) return "image/avif";
        if (lowerName.endsWith(".bmp")) return "image/bmp";
        if (lowerName.endsWith(".gif")) return "image/gif";
        if (lowerName.endsWith(".heif")) return "image/heif";
        if (lowerName.endsWith(".jpeg") || lowerName.endsWith(".jpg")) return "image/jpeg";
        if (lowerName.endsWith(".jp2")) return "image/jp2";
        if (lowerName.endsWith(".jxl")) return "image/jxl";
        if (lowerName.endsWith(".png")) return "image/png";
        if (lowerName.endsWith(".webp")) return "image/webp";
        return "";
    }

    private boolean isSkippableScanDirectory(File directory)
    {
        final String name = directory.getName();
        if (name == null || name.isEmpty()) {
            return false;
        }
        if (name.startsWith(".")) {
            return true;
        }

        final File parent = directory.getParentFile();
        final String parentName = parent == null ? "" : parent.getName();
        return "Android".equals(parentName) && ("data".equals(name) || "obb".equals(name));
    }

    private void scanSupportedFiles(File root, Map<String, FolderSummary> folders, ArrayList<JSONObject> files)
    {
        final ArrayList<File> pending = new ArrayList<>();
        final Set<String> visited = new HashSet<>();
        pending.add(root);

        while (!pending.isEmpty()) {
            final File directory = pending.remove(pending.size() - 1);
            if (directory == null || !directory.isDirectory() || isSkippableScanDirectory(directory)) {
                continue;
            }

            final String directoryPath = directory.getAbsolutePath();
            if (!visited.add(directoryPath)) {
                continue;
            }

            final File[] children = directory.listFiles();
            if (children == null) {
                continue;
            }

            for (File child : children) {
                if (child == null) {
                    continue;
                }
                if (child.isDirectory()) {
                    pending.add(child);
                } else {
                    final String mimeType = mimeTypeForLibraryName(child.getName());
                    if (!child.isFile() || !isSupportedLibraryDocument(child.getName(), mimeType)) {
                        continue;
                    }
                    final File parent = child.getParentFile();
                    if (parent == null) {
                        continue;
                    }
                    final String parentPath = parent.getAbsolutePath();
                    FolderSummary summary = folders.get(parentPath);
                    if (summary == null) {
                        summary = new FolderSummary(parent);
                        folders.put(parentPath, summary);
                    }
                    summary.add(child, categoryForLibraryName(child.getName(), mimeType), isNewModified(child.lastModified()));
                    if (files != null) {
                        try {
                            files.add(scanFileEntry(child));
                        } catch (JSONException e) {
                            Log.w(TAG, "Cannot add scanned file", e);
                        }
                    }
                }
            }
        }
    }

    private JSONObject scanCategoryCounts(FolderSummary summary) throws JSONException
    {
        final JSONObject counts = new JSONObject();
        counts.put(CATEGORY_LOCAL, summary.countForCategory(CATEGORY_LOCAL));
        counts.put(CATEGORY_DOCUMENTS, summary.countForCategory(CATEGORY_DOCUMENTS));
        counts.put(CATEGORY_BOOKS, summary.countForCategory(CATEGORY_BOOKS));
        counts.put(CATEGORY_PICTURES, summary.countForCategory(CATEGORY_PICTURES));
        return counts;
    }

    private JSONObject scanNewCategoryCounts(FolderSummary summary) throws JSONException
    {
        final JSONObject counts = new JSONObject();
        counts.put(CATEGORY_LOCAL, summary.newCountForCategory(CATEGORY_LOCAL));
        counts.put(CATEGORY_DOCUMENTS, summary.newCountForCategory(CATEGORY_DOCUMENTS));
        counts.put(CATEGORY_BOOKS, summary.newCountForCategory(CATEGORY_BOOKS));
        counts.put(CATEGORY_PICTURES, summary.newCountForCategory(CATEGORY_PICTURES));
        return counts;
    }

    private JSONObject scanFolderEntry(FolderSummary summary) throws JSONException
    {
        final JSONObject entry = libraryEntry("folder", summary.folder.getName(), Uri.fromFile(summary.folder).toString(), "", summary.count, summary.modified);
        entry.put("subtitle", categoryCountText(CATEGORY_LOCAL, summary.count));
        entry.put("category", CATEGORY_LOCAL);
        entry.put("count", summary.count);
        entry.put("counts", scanCategoryCounts(summary));
        entry.put("isNew", summary.newCount > 0);
        entry.put("newCount", summary.newCount);
        entry.put("newCounts", scanNewCategoryCounts(summary));
        entry.put("path", summary.folder.getAbsolutePath());
        return entry;
    }

    private JSONObject scanFileEntry(File file) throws JSONException
    {
        final String mimeType = mimeTypeForLibraryName(file.getName());
        final JSONObject entry = libraryEntry("file", file.getName(), Uri.fromFile(file).toString(), mimeType, file.length(), file.lastModified());
        entry.put("category", categoryForLibraryName(file.getName(), mimeType));
        entry.put("subtitle", file.getParent());
        entry.put("path", file.getAbsolutePath());
        if (CATEGORY_PICTURES.equals(entry.optString("category"))) {
            entry.put("thumbnailUri", Uri.fromFile(file).toString());
        }
        return entry;
    }

    private String buildScanningLibraryJson()
    {
        final JSONObject state = new JSONObject();
        try {
            state.put("hasFolder", false);
            state.put("title", "Local");
            state.put("message", "Scanning local storage for Okular documents...");
            state.put("canGoUp", false);
            state.put("needsAllFilesAccess", false);
            state.put("entries", new JSONArray());
            state.put("allFiles", new JSONArray());
            state.put("recent", recentDocumentsJson());
        } catch (JSONException ignored) {
        }
        return state.toString();
    }

    private String buildAllFilesLibraryJson()
    {
        final JSONObject state = new JSONObject();
        final JSONArray entries = new JSONArray();
        try {
            final String selectedPath = libraryPrefs().getString(PREF_SCAN_FOLDER_PATH, "");
            if (selectedPath != null && !selectedPath.isEmpty()) {
                final File selectedFolder = new File(selectedPath);
                final File[] children = selectedFolder.listFiles();
                final ArrayList<JSONObject> files = new ArrayList<>();
                if (children != null) {
                    for (File child : children) {
                        if (child != null && child.isFile() && isSupportedLibraryDocument(child.getName(), mimeTypeForLibraryName(child.getName()))) {
                            files.add(scanFileEntry(child));
                        }
                    }
                }

                final Comparator<JSONObject> byName = (left, right) -> left.optString("name").compareToIgnoreCase(right.optString("name"));
                Collections.sort(files, byName);
                for (JSONObject file : files) {
                    entries.put(file);
                }

                state.put("hasFolder", true);
                state.put("title", selectedFolder.getName().isEmpty() ? selectedFolder.getAbsolutePath() : selectedFolder.getName());
                state.put("message", entries.length() == 0 ? "No supported Okular documents in this folder." : "");
                state.put("canGoUp", true);
                state.put("needsAllFilesAccess", false);
                state.put("entries", entries);
                state.put("allFiles", entries);
                state.put("recent", recentDocumentsJson());
                return state.toString();
            }

            final HashMap<String, FolderSummary> folders = new HashMap<>();
            final ArrayList<JSONObject> allFiles = new ArrayList<>();
            scanSupportedFiles(Environment.getExternalStorageDirectory(), folders, allFiles);
            final ArrayList<FolderSummary> summaries = new ArrayList<>(folders.values());
            Collections.sort(summaries, (left, right) -> left.folder.getName().compareToIgnoreCase(right.folder.getName()));
            for (FolderSummary summary : summaries) {
                entries.put(scanFolderEntry(summary));
            }
            Collections.sort(allFiles, (left, right) -> left.optString("name").compareToIgnoreCase(right.optString("name")));
            final JSONArray allFileEntries = new JSONArray();
            for (JSONObject file : allFiles) {
                allFileEntries.put(file);
            }

            state.put("hasFolder", true);
            state.put("title", "Local");
            state.put("message", entries.length() == 0 ? "No supported Okular documents found in shared storage." : "");
            state.put("canGoUp", false);
            state.put("needsAllFilesAccess", false);
            state.put("entries", entries);
            state.put("allFiles", allFileEntries);
            state.put("recent", recentDocumentsJson());
        } catch (Exception e) {
            Log.e(TAG, "Cannot scan shared storage", e);
            try {
                state.put("hasFolder", false);
                state.put("title", "Local");
                state.put("message", "Okular could not scan storage. Try the folder picker instead.");
                state.put("canGoUp", false);
                state.put("needsAllFilesAccess", false);
                state.put("entries", entries);
                state.put("allFiles", new JSONArray());
                state.put("recent", recentDocumentsJson());
            } catch (JSONException ignored) {
            }
        }
        return state.toString();
    }

    private String buildFolderPickerLibraryJson()
    {
        final JSONObject state = new JSONObject();
        final JSONArray entries = new JSONArray();
        try {
            final String treeUriString = libraryPrefs().getString(PREF_TREE_URI, "");
            if (treeUriString == null || treeUriString.isEmpty()) {
                state.put("hasFolder", false);
                state.put("title", "Local");
                state.put("message", "Allow all files access to scan your Okular documents like MX Player, or choose one folder manually.");
                state.put("canGoUp", false);
                state.put("needsAllFilesAccess", true);
                state.put("entries", entries);
                state.put("allFiles", new JSONArray());
                state.put("recent", recentDocumentsJson());
                return state.toString();
            }

            final Uri treeUri = Uri.parse(treeUriString);
            final Uri folderUri = Uri.parse(currentLibraryFolderUri());
            final String folderDocumentId = documentIdForFolder(treeUri, folderUri);
            final Uri childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, folderDocumentId);
            final ArrayList<JSONObject> folders = new ArrayList<>();
            final ArrayList<JSONObject> files = new ArrayList<>();
            final String[] columns = {
                Document.COLUMN_DOCUMENT_ID,
                Document.COLUMN_DISPLAY_NAME,
                Document.COLUMN_MIME_TYPE,
                Document.COLUMN_SIZE,
                Document.COLUMN_LAST_MODIFIED
            };

            try (Cursor cursor = getContentResolver().query(childrenUri, columns, null, null, null)) {
                if (cursor != null) {
                    while (cursor.moveToNext()) {
                        final String documentId = cursor.getString(cursor.getColumnIndexOrThrow(Document.COLUMN_DOCUMENT_ID));
                        final String name = cursor.getString(cursor.getColumnIndexOrThrow(Document.COLUMN_DISPLAY_NAME));
                        final String mimeType = cursor.getString(cursor.getColumnIndexOrThrow(Document.COLUMN_MIME_TYPE));
                        final long size = cursor.getLong(cursor.getColumnIndexOrThrow(Document.COLUMN_SIZE));
                        final long modified = cursor.getLong(cursor.getColumnIndexOrThrow(Document.COLUMN_LAST_MODIFIED));
                        final Uri documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId);

                        if (Document.MIME_TYPE_DIR.equals(mimeType)) {
                            folders.add(libraryEntry("folder", name, documentUri.toString(), mimeType, size, modified));
                        } else if (isSupportedLibraryDocument(name, mimeType)) {
                            final JSONObject fileEntry = libraryEntry("file", name, documentUri.toString(), mimeType, size, modified);
                            fileEntry.put("category", categoryForLibraryName(name, mimeType));
                            if (CATEGORY_PICTURES.equals(fileEntry.optString("category"))) {
                                fileEntry.put("thumbnailUri", documentUri.toString());
                            }
                            files.add(fileEntry);
                        }
                    }
                }
            }

            final Comparator<JSONObject> byName = (left, right) -> left.optString("name").compareToIgnoreCase(right.optString("name"));
            Collections.sort(folders, byName);
            Collections.sort(files, byName);
            for (JSONObject folder : folders) {
                entries.put(folder);
            }
            for (JSONObject file : files) {
                entries.put(file);
            }

            state.put("hasFolder", true);
            state.put("title", displayNameForDocumentUri(folderUri));
            state.put("message", entries.length() == 0 ? "No supported Okular documents in this folder." : "");
            state.put("canGoUp", libraryStack().size() > 1);
            state.put("needsAllFilesAccess", true);
            state.put("entries", entries);
            state.put("allFiles", entries);
            state.put("recent", recentDocumentsJson());
        } catch (Exception e) {
            Log.e(TAG, "Cannot build library", e);
            try {
                state.put("hasFolder", false);
                state.put("title", "Folders");
                state.put("message", "Okular could not read that folder. Choose it again or pick another folder.");
                state.put("canGoUp", false);
                state.put("needsAllFilesAccess", true);
                state.put("entries", entries);
                state.put("allFiles", new JSONArray());
                state.put("recent", recentDocumentsJson());
            } catch (JSONException ignored) {
            }
        }
        return state.toString();
    }

    public void publishLibrary()
    {
        final int generation = ++libraryScanGeneration;
        if (!hasAllFilesAccess()) {
            publishLibraryJson(buildFolderPickerLibraryJson());
            return;
        }

        final SharedPreferences prefs = libraryPrefs();
        final String selectedPath = prefs.getString(PREF_SCAN_FOLDER_PATH, "");
        final boolean scanningOverview = selectedPath == null || selectedPath.isEmpty();
        final String cachedOverview = scanningOverview ? prefs.getString(PREF_LIBRARY_OVERVIEW_CACHE_JSON, "") : "";
        if (cachedOverview != null && !cachedOverview.isEmpty()) {
            publishLibraryJson(cachedOverview);
        } else {
            publishLibraryJson(buildScanningLibraryJson());
        }

        new Thread(() -> {
            final String json = buildAllFilesLibraryJson();
            if (scanningOverview) {
                prefs.edit()
                        .putString(PREF_LIBRARY_OVERVIEW_CACHE_JSON, json)
                        .putLong(PREF_LIBRARY_OVERVIEW_CACHE_TIME, System.currentTimeMillis())
                        .apply();
            }
            runOnUiThread(() -> {
                if (generation == libraryScanGeneration) {
                    publishLibraryJson(json);
                }
            });
        }, "OkularLibraryScanner").start();
    }

    private void publishLibraryJson(String json)
    {
        try {
            FileClass.updateLibrary(json);
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "Native Okular library state handler is not ready yet", e);
        }
    }

    public void setReaderMode(boolean enabled)
    {
        readerModeEnabled = enabled;
        applyReaderMode();
    }

    private boolean hasActiveReaderDocument()
    {
        return readerModeEnabled || currentDocumentUri != null;
    }

    private void handleBackRequest()
    {
        Log.v(TAG, "Back requested; readerModeEnabled=" + readerModeEnabled + ", hasDocument=" + (currentDocumentUri != null));
        if (hasActiveReaderDocument()) {
            FileClass.closeDocument();
        } else {
            moveTaskToBack(false);
        }
    }

    private void applyReaderMode()
    {
        runOnUiThread(() -> {
            final Window window = getWindow();
            if (window == null) {
                return;
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                window.setStatusBarColor(readerModeEnabled ? Color.BLACK : Color.TRANSPARENT);
                window.setNavigationBarColor(readerModeEnabled ? Color.TRANSPARENT : Color.rgb(35, 38, 41));
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                final WindowManager.LayoutParams attributes = window.getAttributes();
                attributes.layoutInDisplayCutoutMode = readerModeEnabled
                        ? WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                        : WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT;
                window.setAttributes(attributes);
            }

            final View decorView = window.getDecorView();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.setDecorFitsSystemWindows(false);
                final WindowInsetsController controller = window.getInsetsController();
                if (controller == null) {
                    return;
                }

                controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                if (readerModeEnabled) {
                    controller.setSystemBarsAppearance(0, WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS);
                    controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                } else {
                    controller.show(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                    controller.setSystemBarsAppearance(WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS, WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS);
                }
            } else if (decorView != null) {
                if (readerModeEnabled) {
                    decorView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
                } else {
                    int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
                    }
                    decorView.setSystemUiVisibility(flags);
                }
            }
        });
    }

    public int systemBarDimensionDp(String resourceName)
    {
        final int resourceId = getResources().getIdentifier(resourceName, "dimen", "android");
        if (resourceId == 0) {
            return 0;
        }

        final int pixels = getResources().getDimensionPixelSize(resourceId);
        final float density = getResources().getDisplayMetrics().density;
        return density > 0 ? Math.round(pixels / density) : pixels;
    }

    public String contentUrlToFd(String url)
    {
        final Uri uri = Uri.parse(url);
        if ("fd".equals(uri.getScheme()) || "file".equals(uri.getScheme())) {
            return url;
        }

        try {
            ContentResolver resolver = getBaseContext().getContentResolver();
            ParcelFileDescriptor fdObject = resolver.openFileDescriptor(uri, "r");
            if (fdObject == null) {
                Log.e(TAG, "Cannot open file descriptor");
                return "";
            }
            return addOkularOpenHints(Uri.parse("fd:///" + fdObject.detachFd()), uri, null).toString();
        } catch (FileNotFoundException e) {
            Log.e(TAG, "Cannot find file", e);
        }
        return "";
    }

    private String mimeTypeForUri(Uri uri, String intentType)
    {
        if (intentType != null && !intentType.isEmpty()) {
            return intentType;
        }

        try {
            return getBaseContext().getContentResolver().getType(uri);
        } catch (Exception e) {
            Log.w(TAG, "Cannot query MIME type", e);
        }

        return "";
    }

    private String displayNameForUri(Uri uri)
    {
        try (Cursor cursor = getBaseContext().getContentResolver().query(uri, new String[] { OpenableColumns.DISPLAY_NAME }, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                final int displayNameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (displayNameColumn >= 0) {
                    final String displayName = cursor.getString(displayNameColumn);
                    if (displayName != null && !displayName.isEmpty()) {
                        return displayName;
                    }
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Cannot query display name", e);
        }

        final String lastPathSegment = uri.getLastPathSegment();
        return lastPathSegment != null ? lastPathSegment : "";
    }

    private Uri addOkularOpenHints(Uri uri, Uri originalUri, String intentType)
    {
        final Uri.Builder builder = uri.buildUpon();
        final String mimeType = mimeTypeForUri(originalUri, intentType);
        if (mimeType != null && !mimeType.isEmpty()) {
            builder.appendQueryParameter(OKULAR_MIME_TYPE_QUERY_ITEM, mimeType);
        }

        final String displayName = displayNameForUri(originalUri);
        if (displayName != null && !displayName.isEmpty()) {
            builder.appendQueryParameter(OKULAR_FILE_NAME_QUERY_ITEM, displayName);
        }

        return builder.build();
    }


    private void displayUri(Uri uri, String intentType)
    {
        if (uri == null)
            return;

        final Uri originalUri = uri;
        final String scheme = uri.getScheme();
        if (scheme == null) {
            Log.e(TAG, "Cannot open URI with no scheme");
            return;
        }

        if (!scheme.equals("file") && !scheme.equals("fd")) {
            try {
                ContentResolver resolver = getBaseContext().getContentResolver();
                ParcelFileDescriptor fdObject = resolver.openFileDescriptor(uri, "r");
                if (fdObject == null) {
                    Log.e(TAG, "Cannot open file descriptor");
                    return;
                }
                uri = addOkularOpenHints(Uri.parse("fd:///" + fdObject.detachFd()), uri, intentType);
            } catch (Exception e) {
                e.printStackTrace();

                //TODO: emit warning that couldn't be opened
                Log.e(TAG, "Failed to open URI", e);
                return;
            }
        } else {
            uri = addOkularOpenHints(uri, uri, intentType);
        }

        Log.v(TAG, "Opening URI with scheme: " + uri.getScheme());
        currentDocumentUri = originalUri;
        currentDocumentMimeType = mimeTypeForUri(originalUri, intentType);
        if (currentDocumentMimeType == null || currentDocumentMimeType.isEmpty()) {
            currentDocumentMimeType = mimeTypeForLibraryName(displayNameForUri(originalUri));
        }
        currentDocumentName = displayNameForUri(originalUri);
        recordRecentDocument(originalUri, intentType);
        FileClass.openUri(uri.toString());
    }

    private Uri uriFromIntent(Intent intent)
    {
        if (intent == null) {
            return null;
        }

        final Uri dataUri = intent.getData();
        if (dataUri != null) {
            return dataUri;
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                final Uri stream = intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri.class);
                if (stream != null) {
                    return stream;
                }
            } else {
                final Object stream = intent.getParcelableExtra(Intent.EXTRA_STREAM);
                if (stream instanceof Uri) {
                    return (Uri)stream;
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Cannot read intent stream URI", e);
        }

        final ClipData clipData = intent.getClipData();
        if (clipData != null && clipData.getItemCount() > 0 && clipData.getItemAt(0) != null) {
            return clipData.getItemAt(0).getUri();
        }

        return null;
    }

    public void handleViewIntent() {
        final Intent bundleIntent = getIntent();
        if (bundleIntent == null)
            return;

        final String action = bundleIntent.getAction();
        Log.v(TAG, "Handling action: " + action);
        if (Intent.ACTION_VIEW.equals(action)
                || Intent.ACTION_SEND.equals(action)
                || Intent.ACTION_SEND_MULTIPLE.equals(action)) {
            displayUri(uriFromIntent(bundleIntent), bundleIntent.getType());
        }
    }

    @Override
    protected void onResume()
    {
        super.onResume();
        FileClass.setActivity(this);
        publishLibrary();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        FileClass.setActivity(this);

        try {
            handleViewIntent();
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "Native Okular URI handler is not ready yet", e);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data)
    {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode != REQUEST_LIBRARY_FOLDER || resultCode != RESULT_OK || data == null || data.getData() == null) {
            return;
        }

        final Uri treeUri = data.getData();
        int takeFlags = data.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION;
        if (takeFlags == 0) {
            takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION;
        }
        try {
            getContentResolver().takePersistableUriPermission(treeUri, takeFlags);
        } catch (SecurityException e) {
            Log.w(TAG, "Cannot persist folder permission", e);
        }

        final ArrayList<String> stack = new ArrayList<>();
        stack.add(treeUri.toString());
        libraryPrefs().edit()
                .putString(PREF_TREE_URI, treeUri.toString())
                .apply();
        saveLibraryStack(stack);
        publishLibrary();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus)
    {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            applyReaderMode();
        }
    }
}
