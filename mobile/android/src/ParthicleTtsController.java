/*
    SPDX-FileCopyrightText: 2026 Parth Ganguly

    SPDX-License-Identifier: GPL-2.0-or-later
*/

package org.kde.something;

import android.content.Context;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.speech.tts.Voice;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.text.BreakIterator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class ParthicleTtsController
{
    private static final String TAG = "ParthicleTts";
    private static final int FALLBACK_MAX_INPUT_LENGTH = 4000;

    private final Context applicationContext;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService discoveryExecutor = Executors.newSingleThreadExecutor();
    private final Set<String> pendingUtterances = new HashSet<>();
    private final Set<String> unavailableEnginePackages = new HashSet<>();
    private final List<Voice> cachedVoices = new ArrayList<>();
    private final Map<String, Voice> cachedVoicesByName = new HashMap<>();

    private TextToSpeech textToSpeech;
    private int engineGeneration = 0;
    private long utteranceSequence = 0;
    private String requestedEnginePackage = "";
    private String activeEnginePackage = "";
    private String selectedVoiceName = "";
    private String state = "initializing";
    private String errorCode = "";
    private String statusMessage = "";
    private float speechRate = 1.0f;
    private float speechPitch = 1.0f;
    private boolean speaking = false;
    private String cachedEnginesJson = "[]";
    private String cachedVoicesJson = "[]";

    ParthicleTtsController(Context context)
    {
        applicationContext = context.getApplicationContext();
        mainHandler.post(() -> initializeEngineOnMain(""));
    }

    synchronized String enginesJson()
    {
        return cachedEnginesJson;
    }

    synchronized String voicesJson(String enginePackage)
    {
        final String requested = safeString(enginePackage);
        if (!requested.isEmpty() && !requested.equals(activeEnginePackage)) {
            return "[]";
        }
        return cachedVoicesJson;
    }

    boolean useEngine(String enginePackage)
    {
        final String requested = safeString(enginePackage);
        synchronized (this) {
            if (!requested.isEmpty() && unavailableEnginePackages.contains(requested)) {
                state = "error";
                errorCode = "engine_unavailable";
                statusMessage = "That TTS engine is unavailable to Parthicle Reader in this session.";
                speaking = false;
                return false;
            }
            if (requested.equals(activeEnginePackage) && ("ready".equals(state) || "speaking".equals(state))) {
                return true;
            }
            requestedEnginePackage = requested;
            activeEnginePackage = "";
            selectedVoiceName = "";
            state = "initializing";
            errorCode = "";
            statusMessage = "";
            speaking = false;
            pendingUtterances.clear();
            cachedVoices.clear();
            cachedVoicesByName.clear();
            cachedVoicesJson = "[]";
        }
        mainHandler.post(() -> initializeEngineOnMain(requested));
        return true;
    }

    boolean speak(String text)
    {
        final String cleanText = safeString(text).trim();
        if (cleanText.isEmpty()) {
            return false;
        }

        final int generation;
        synchronized (this) {
            if (textToSpeech == null || !"ready".equals(state) && !"speaking".equals(state)) {
                return false;
            }
            generation = engineGeneration;
        }

        final List<String> chunks = chunkText(cleanText, maximumInputLength());
        if (chunks.isEmpty()) {
            return false;
        }
        mainHandler.post(() -> speakOnMain(generation, chunks));
        return true;
    }

    void stop()
    {
        mainHandler.post(this::stopOnMain);
    }

    synchronized void setRate(float rate)
    {
        speechRate = clamp(rate, 0.1f, 4.0f);
        final int generation = engineGeneration;
        mainHandler.post(() -> {
            final TextToSpeech current;
            synchronized (ParthicleTtsController.this) {
                if (generation != engineGeneration) {
                    return;
                }
                current = textToSpeech;
            }
            if (current != null && current.setSpeechRate(speechRate) == TextToSpeech.ERROR) {
                setError("speak_failed", "The TTS engine could not apply that speech rate.");
            }
        });
    }

    synchronized void setPitch(float pitch)
    {
        speechPitch = clamp(pitch, 0.1f, 2.0f);
        final int generation = engineGeneration;
        mainHandler.post(() -> {
            final TextToSpeech current;
            synchronized (ParthicleTtsController.this) {
                if (generation != engineGeneration) {
                    return;
                }
                current = textToSpeech;
            }
            if (current != null && current.setPitch(speechPitch) == TextToSpeech.ERROR) {
                setError("speak_failed", "The TTS engine could not apply that pitch.");
            }
        });
    }

    boolean setVoice(String voiceName)
    {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP || safeString(voiceName).isEmpty()) {
            return false;
        }

        final int generation;
        synchronized (this) {
            if (textToSpeech == null || !"ready".equals(state) && !"speaking".equals(state)) {
                return false;
            }
            generation = engineGeneration;
        }
        mainHandler.post(() -> setVoiceOnMain(generation, voiceName));
        return true;
    }

    synchronized String stateJson()
    {
        final JSONObject result = new JSONObject();
        try {
            result.put("state", state);
            result.put("errorCode", errorCode);
            result.put("message", statusMessage);
            result.put("enginePackage", activeEnginePackage.isEmpty() ? requestedEnginePackage : activeEnginePackage);
            result.put("voiceName", selectedVoiceName);
            result.put("rate", speechRate);
            result.put("pitch", speechPitch);
            result.put("speaking", speaking);
        } catch (JSONException ignored) {
        }
        return result.toString();
    }

    void shutdown()
    {
        final TextToSpeech current;
        synchronized (this) {
            engineGeneration++;
            current = textToSpeech;
            textToSpeech = null;
            pendingUtterances.clear();
            cachedVoices.clear();
            cachedVoicesByName.clear();
            cachedVoicesJson = "[]";
            cachedEnginesJson = "[]";
            speaking = false;
            state = "unavailable";
        }
        if (current != null) {
            mainHandler.post(() -> {
                current.stop();
                current.shutdown();
            });
        }
        discoveryExecutor.shutdownNow();
    }

    private void initializeEngineOnMain(String enginePackage)
    {
        final TextToSpeech previous;
        final int generation;
        synchronized (this) {
            previous = textToSpeech;
            textToSpeech = null;
            pendingUtterances.clear();
            speaking = false;
            state = "initializing";
            errorCode = "";
            statusMessage = "";
            requestedEnginePackage = safeString(enginePackage);
            cachedVoices.clear();
            cachedVoicesByName.clear();
            cachedVoicesJson = "[]";
            generation = ++engineGeneration;
        }

        if (previous != null) {
            previous.stop();
            previous.shutdown();
        }

        try {
            final TextToSpeech.OnInitListener listener = status -> mainHandler.post(() -> finishInitialization(generation, status));
            final TextToSpeech created = enginePackage == null || enginePackage.isEmpty()
                    ? new TextToSpeech(applicationContext, listener)
                    : new TextToSpeech(applicationContext, listener, enginePackage);
            synchronized (this) {
                if (generation != engineGeneration) {
                    created.shutdown();
                    return;
                }
                textToSpeech = created;
            }
        } catch (Exception e) {
            Log.e(TAG, "Cannot initialize Android TTS", e);
            setError("init_failed", "TTS engine failed to initialize.");
        }
    }

    private void finishInitialization(int generation, int status)
    {
        final TextToSpeech current;
        final String requested;
        synchronized (this) {
            if (generation != engineGeneration) {
                return;
            }
            current = textToSpeech;
            requested = requestedEnginePackage;
        }

        if (status != TextToSpeech.SUCCESS || current == null) {
            if (!requested.isEmpty()) {
                synchronized (this) {
                    if (generation != engineGeneration) {
                        return;
                    }
                    unavailableEnginePackages.add(requested);
                }
                Log.w(TAG, "TTS engine is unavailable for this session: " + requested + "; falling back to the default engine");
                initializeEngineOnMain("");
                return;
            }
            setError(current == null ? "no_engine" : "init_failed",
                    current == null ? "No TTS engine installed." : "TTS engine failed to initialize.");
            return;
        }

        current.setOnUtteranceProgressListener(new UtteranceProgressListener() {
            @Override
            public void onStart(String utteranceId)
            {
                synchronized (ParthicleTtsController.this) {
                    if (generation != engineGeneration) {
                        return;
                    }
                    speaking = true;
                    state = "speaking";
                }
            }

            @Override
            public void onDone(String utteranceId)
            {
                completeUtterance(generation, utteranceId, false);
            }

            @Override
            public void onError(String utteranceId)
            {
                completeUtterance(generation, utteranceId, true);
            }

            @Override
            public void onError(String utteranceId, int errorCode)
            {
                completeUtterance(generation, utteranceId, true);
            }
        });

        current.setSpeechRate(speechRate);
        current.setPitch(speechPitch);
        discoveryExecutor.execute(() -> refreshDiscoveryCache(generation, current));
    }

    private void speakOnMain(int generation, List<String> chunks)
    {
        final TextToSpeech current;
        final long sequence;
        synchronized (this) {
            if (generation != engineGeneration || textToSpeech == null || !"ready".equals(state) && !"speaking".equals(state)) {
                return;
            }
            current = textToSpeech;
            sequence = ++utteranceSequence;
            pendingUtterances.clear();
            speaking = true;
            state = "speaking";
            errorCode = "";
            statusMessage = "";
        }

        current.stop();

        for (int i = 0; i < chunks.size(); ++i) {
            final String utteranceId = "parthicle-" + sequence + "-" + i;
            final Bundle parameters = new Bundle();
            synchronized (this) {
                pendingUtterances.add(utteranceId);
            }
            final int result = current.speak(chunks.get(i), i == 0 ? TextToSpeech.QUEUE_FLUSH : TextToSpeech.QUEUE_ADD, parameters, utteranceId);
            if (result == TextToSpeech.ERROR) {
                current.stop();
                synchronized (this) {
                    pendingUtterances.clear();
                    speaking = false;
                }
                setError("speak_failed", "The TTS engine could not speak this page.");
                return;
            }
        }
    }

    private void stopOnMain()
    {
        final TextToSpeech current;
        synchronized (this) {
            current = textToSpeech;
            pendingUtterances.clear();
            speaking = false;
            if (!"error".equals(state) && !"initializing".equals(state)) {
                state = current == null ? "unavailable" : "ready";
            }
        }
        if (current != null) {
            current.stop();
        }
    }

    private void setVoiceOnMain(int generation, String voiceName)
    {
        final TextToSpeech current;
        final Voice requestedVoice;
        synchronized (this) {
            if (generation != engineGeneration) {
                return;
            }
            current = textToSpeech;
            requestedVoice = cachedVoicesByName.get(voiceName);
        }
        if (current == null || requestedVoice == null) {
            setError("missing_voice_data", "Voice data missing; install voice data in Android TTS settings.");
            return;
        }

        if (current.setVoice(requestedVoice) == TextToSpeech.SUCCESS) {
            synchronized (this) {
                if (generation != engineGeneration) {
                    return;
                }
                selectedVoiceName = voiceName;
                state = "ready";
                errorCode = "";
                statusMessage = "";
                cachedVoicesJson = buildVoicesJson(cachedVoices, requestedVoice, selectedVoiceName);
            }
        } else {
            setError("missing_voice_data", "Voice data missing; install voice data in Android TTS settings.");
        }
    }

    private void refreshDiscoveryCache(int generation, TextToSpeech current)
    {
        final List<TextToSpeech.EngineInfo> engines = new ArrayList<>();
        final List<Voice> voices = new ArrayList<>();
        final String defaultEngine;
        final Voice currentVoice;
        final int languageStatus;

        try {
            defaultEngine = safeString(current.getDefaultEngine());
            currentVoice = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP ? current.getVoice() : null;
            languageStatus = current.isLanguageAvailable(Locale.getDefault());
        } catch (Exception e) {
            Log.w(TAG, "Cannot read Android TTS defaults", e);
            setError("init_failed", "TTS engine failed to initialize.");
            return;
        }

        try {
            final List<TextToSpeech.EngineInfo> availableEngines = current.getEngines();
            if (availableEngines != null) {
                engines.addAll(availableEngines);
            }
        } catch (Exception e) {
            Log.w(TAG, "Cannot list Android TTS engines", e);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                final Set<Voice> availableVoices = current.getVoices();
                if (availableVoices != null) {
                    voices.addAll(availableVoices);
                }
            } catch (Exception e) {
                Log.w(TAG, "Cannot list Android TTS voices", e);
            }
        }

        Collections.sort(engines, Comparator.comparing(engine -> safeString(engine.label), String.CASE_INSENSITIVE_ORDER));
        Collections.sort(voices, Comparator.comparing(ParthicleTtsController::voiceLabel, String.CASE_INSENSITIVE_ORDER));

        synchronized (this) {
            if (generation != engineGeneration || current != textToSpeech) {
                return;
            }
            activeEnginePackage = requestedEnginePackage.isEmpty() ? defaultEngine : requestedEnginePackage;
            selectedVoiceName = currentVoice == null ? "" : currentVoice.getName();
            cachedEnginesJson = buildEnginesJson(engines, defaultEngine, activeEnginePackage, unavailableEnginePackages);
            cachedVoices.clear();
            cachedVoices.addAll(voices);
            cachedVoicesByName.clear();
            for (Voice voice : voices) {
                cachedVoicesByName.put(voice.getName(), voice);
            }
            cachedVoicesJson = buildVoicesJson(cachedVoices, currentVoice, selectedVoiceName);
            state = "ready";
            if (languageStatus == TextToSpeech.LANG_MISSING_DATA) {
                errorCode = "missing_voice_data";
                statusMessage = "Voice data missing; install voice data in Android TTS settings.";
            } else {
                errorCode = "";
                statusMessage = "";
            }
        }
    }

    private static String buildEnginesJson(List<TextToSpeech.EngineInfo> engines, String defaultEngine,
            String selectedEngine, Set<String> unavailableEngines)
    {
        final JSONArray result = new JSONArray();
        boolean selectedEngineIncluded = false;
        for (TextToSpeech.EngineInfo engine : engines) {
            final String packageName = safeString(engine.name);
            if (packageName.isEmpty() || unavailableEngines.contains(packageName)) {
                continue;
            }
            try {
                final JSONObject item = new JSONObject();
                item.put("package", packageName);
                item.put("label", safeString(engine.label).isEmpty() ? packageName : safeString(engine.label));
                item.put("isDefault", packageName.equals(defaultEngine));
                item.put("selected", packageName.equals(selectedEngine));
                result.put(item);
                selectedEngineIncluded |= packageName.equals(selectedEngine);
            } catch (JSONException ignored) {
            }
        }
        if (!selectedEngineIncluded && !selectedEngine.isEmpty() && !unavailableEngines.contains(selectedEngine)) {
            try {
                final JSONObject item = new JSONObject();
                item.put("package", selectedEngine);
                item.put("label", selectedEngine);
                item.put("isDefault", selectedEngine.equals(defaultEngine));
                item.put("selected", true);
                result.put(item);
            } catch (JSONException ignored) {
            }
        }
        return result.toString();
    }

    private static String buildVoicesJson(List<Voice> voices, Voice currentVoice, String selectedVoiceName)
    {
        final JSONArray result = new JSONArray();
        for (Voice voice : voices) {
            try {
                final JSONObject item = new JSONObject();
                item.put("name", voice.getName());
                item.put("label", voiceLabel(voice));
                item.put("locale", voice.getLocale() == null ? "" : voice.getLocale().toLanguageTag());
                item.put("quality", voice.getQuality());
                item.put("latency", voice.getLatency());
                item.put("networkRequired", voice.isNetworkConnectionRequired());
                item.put("selected", voice.getName().equals(selectedVoiceName)
                        || selectedVoiceName.isEmpty() && voice.equals(currentVoice));
                final JSONArray features = new JSONArray();
                if (voice.getFeatures() != null) {
                    for (String feature : voice.getFeatures()) {
                        features.put(feature);
                    }
                }
                item.put("features", features);
                result.put(item);
            } catch (JSONException ignored) {
            }
        }
        return result.toString();
    }

    private synchronized void completeUtterance(int generation, String utteranceId, boolean failed)
    {
        if (generation != engineGeneration) {
            return;
        }
        pendingUtterances.remove(utteranceId);
        if (failed) {
            pendingUtterances.clear();
            speaking = false;
            state = "error";
            errorCode = "speak_failed";
            statusMessage = "The TTS engine could not speak this page.";
        } else if (pendingUtterances.isEmpty()) {
            speaking = false;
            state = "ready";
        }
    }

    private synchronized void setError(String code, String message)
    {
        state = "error";
        errorCode = code;
        statusMessage = message;
        speaking = false;
        pendingUtterances.clear();
    }

    private static int maximumInputLength()
    {
        final int reported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2
                ? TextToSpeech.getMaxSpeechInputLength()
                : FALLBACK_MAX_INPUT_LENGTH;
        return Math.max(256, reported - 16);
    }

    private static List<String> chunkText(String text, int maximumLength)
    {
        final ArrayList<String> chunks = new ArrayList<>();
        final BreakIterator sentenceIterator = BreakIterator.getSentenceInstance(Locale.getDefault());
        final String[] paragraphs = text.split("(?:\\r?\\n){2,}|\\r?\\n");
        final StringBuilder currentChunk = new StringBuilder();

        for (String paragraph : paragraphs) {
            final String cleanParagraph = paragraph.trim();
            if (cleanParagraph.isEmpty()) {
                continue;
            }
            sentenceIterator.setText(cleanParagraph);
            int start = sentenceIterator.first();
            for (int end = sentenceIterator.next(); end != BreakIterator.DONE; start = end, end = sentenceIterator.next()) {
                appendSegment(chunks, currentChunk, cleanParagraph.substring(start, end).trim(), maximumLength);
            }
        }
        flushChunk(chunks, currentChunk);
        return chunks;
    }

    private static void appendSegment(List<String> chunks, StringBuilder currentChunk, String segment, int maximumLength)
    {
        if (segment.isEmpty()) {
            return;
        }
        if (segment.length() > maximumLength) {
            flushChunk(chunks, currentChunk);
            splitLongSegment(chunks, segment, maximumLength);
            return;
        }
        final int separatorLength = currentChunk.length() == 0 ? 0 : 1;
        if (currentChunk.length() + separatorLength + segment.length() > maximumLength) {
            flushChunk(chunks, currentChunk);
        }
        if (currentChunk.length() > 0) {
            currentChunk.append(' ');
        }
        currentChunk.append(segment);
    }

    private static void splitLongSegment(List<String> chunks, String segment, int maximumLength)
    {
        int offset = 0;
        while (offset < segment.length()) {
            int end = Math.min(segment.length(), offset + maximumLength);
            if (end < segment.length()) {
                int wordBoundary = end;
                while (wordBoundary > offset + maximumLength / 2 && !Character.isWhitespace(segment.charAt(wordBoundary - 1))) {
                    wordBoundary--;
                }
                if (wordBoundary > offset + maximumLength / 2) {
                    end = wordBoundary;
                }
                if (end > offset && Character.isHighSurrogate(segment.charAt(end - 1))) {
                    end--;
                }
            }
            final String chunk = segment.substring(offset, end).trim();
            if (!chunk.isEmpty()) {
                chunks.add(chunk);
            }
            offset = end;
            while (offset < segment.length() && Character.isWhitespace(segment.charAt(offset))) {
                offset++;
            }
        }
    }

    private static void flushChunk(List<String> chunks, StringBuilder currentChunk)
    {
        if (currentChunk.length() > 0) {
            chunks.add(currentChunk.toString());
            currentChunk.setLength(0);
        }
    }

    private static String voiceLabel(Voice voice)
    {
        final String locale = voice.getLocale() == null ? "" : voice.getLocale().getDisplayName();
        return locale.isEmpty() ? voice.getName() : locale + " - " + voice.getName();
    }

    private static String safeString(String value)
    {
        return value == null ? "" : value;
    }

    private static float clamp(float value, float minimum, float maximum)
    {
        return Math.max(minimum, Math.min(maximum, value));
    }
}
