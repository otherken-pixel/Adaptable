import { useState, useEffect, useCallback, useRef } from 'react';

// Extend window for webkit prefixes
declare global {
  interface Window {
    SpeechRecognition: any;
    webkitSpeechRecognition: any;
  }
}

interface UseCookModeSpeechProps {
  onCommand: (command: string) => void;
  language?: string;
}

/**
 * A hook that manages the Speech Recognition API with workarounds for Safari's 
 * aggressive auto-pause behavior, and manages the Wake-Lock API to keep the screen on.
 */
export function useCookModeSpeech({ onCommand, language = 'en-US' }: UseCookModeSpeechProps) {
  const [isListening, setIsListening] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const recognitionRef = useRef<any>(null);
  const wakeLockRef = useRef<any>(null);
  const shouldListenRef = useRef(false);

  // Initialize Speech Recognition
  useEffect(() => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setError('Speech Recognition API is not supported in this browser.');
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = false;
    recognition.lang = language;

    recognition.onresult = (event: any) => {
      const transcript = event.results[event.results.length - 1][0].transcript.trim().toLowerCase();
      onCommand(transcript);
    };

    recognition.onerror = (event: any) => {
      console.error("Speech recognition error", event.error);
      // 'no-speech' is common if there is silence, just ignore and let onend restart it
      if (event.error !== 'no-speech') {
        setError(event.error);
      }
    };

    // The critical workaround for Safari: Safari stops recognition automatically
    // after a short period of silence. We hook into 'onend' and restart it 
    // immediately if our internal state says we should still be listening.
    recognition.onend = () => {
      if (shouldListenRef.current) {
        try {
          recognition.start();
        } catch (e) {
          console.error("Failed to restart recognition:", e);
        }
      } else {
        setIsListening(false);
      }
    };

    recognitionRef.current = recognition;

    return () => {
      shouldListenRef.current = false;
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
    };
  }, [language, onCommand]);

  // Request Wake Lock
  const requestWakeLock = async () => {
    if ('wakeLock' in navigator) {
      try {
        wakeLockRef.current = await (navigator as any).wakeLock.request('screen');
        console.log('Screen Wake Lock is active');
      } catch (err: any) {
        console.warn(`Wake Lock error: ${err.name}, ${err.message}`);
      }
    } else {
      console.warn('Wake Lock API not supported. Screen may sleep.');
    }
  };

  const releaseWakeLock = () => {
    if (wakeLockRef.current !== null) {
      wakeLockRef.current.release()
        .then(() => {
          wakeLockRef.current = null;
        });
    }
  };

  const startListening = useCallback(() => {
    setError(null);
    shouldListenRef.current = true;
    try {
      recognitionRef.current?.start();
      setIsListening(true);
      requestWakeLock();
    } catch (e) {
      console.error("Error starting recognition", e);
    }
  }, []);

  const stopListening = useCallback(() => {
    shouldListenRef.current = false;
    recognitionRef.current?.stop();
    setIsListening(false);
    releaseWakeLock();
  }, []);

  // Handle visibility change for Wake Lock
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (wakeLockRef.current !== null && document.visibilityState === 'visible') {
        requestWakeLock();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, []);

  return {
    isListening,
    error,
    startListening,
    stopListening
  };
}
