// Transition types for segment entry/exit
export type TransitionType =
  | 'fade'        // Opacity crossfade (default)
  | 'cut'         // Hard cut, no transition
  | 'slide-left'  // Slides in from right
  | 'slide-right' // Slides in from left
  | 'slide-up'    // Slides up from bottom
  | 'slide-down'  // Slides down from top
  | 'zoom-in'     // Zooms in from small
  | 'zoom-out'    // Starts big, shrinks to fit
  | 'wipe-left'   // Horizontal wipe reveal
  | 'blur';       // Blur in/out

// Ken Burns camera motion types
export type KenBurnsType =
  | 'zoom-in'     // Slow zoom in (default)
  | 'zoom-out'    // Slow zoom out
  | 'pan-left'    // Pan from right to left
  | 'pan-right'   // Pan from left to right
  | 'pan-up'      // Pan from bottom to top
  | 'pan-down'    // Pan from top to bottom
  | 'none';       // Static, no motion

// Text animation types for subtitles
export type TextAnimationType =
  | 'pop'         // Word-by-word with bounce (default)
  | 'typewriter'  // Character by character
  | 'slide-up'    // Words slide up into place
  | 'fade'        // Simple fade in all at once
  | 'wave'        // Wave effect across words
  | 'none';       // Static text, no animation

// Segment: A voice line paired with media (video or image)
export interface Segment {
  // Voice line for this segment (null for silent segments)
  voice: string | null;

  // Media source - video file or image
  media: string;

  // Is this media an image? (auto-detected from extension if not specified)
  isImage?: boolean;

  // For videos: start time in seconds (default: 0)
  mediaStartTime?: number;

  // Duration in seconds (required for images, optional for videos with voice)
  // If voice is provided, duration is derived from voice length
  duration?: number;

  // Subtitle text to display (optional, defaults to empty)
  subtitle?: string;

  // Crop settings for 9:16 framing (optional)
  // x, y are the top-left corner of the crop region in the source
  crop?: {
    x: number;
    y: number;
    width?: number;  // defaults to maintain 9:16 from source height
    height?: number;
  };

  // Sound effect to play during this segment (optional)
  sfx?: string;

  // SFX volume (0-1, default: 0.5)
  sfxVolume?: number;

  // SFX start offset in seconds (default: 0, plays at segment start)
  sfxOffset?: number;

  // === NEW: Animation/Transition Options ===

  // How this segment transitions IN (default: 'fade')
  transition?: TransitionType;

  // Camera motion during segment (default: 'zoom-in')
  kenBurns?: KenBurnsType;

  // Text animation style for subtitle (default: 'pop')
  textAnimation?: TextAnimationType;
}

// Full video manifest
export interface DevlogVideoProps {
  // Video metadata
  fps: number;

  // Segments in order
  segments: Segment[];

  // Style options
  style?: {
    // Subtitle position: 'top', 'center', 'bottom' (default: 'bottom')
    subtitlePosition?: 'top' | 'center' | 'bottom';

    // Show subtitles? (default: true)
    showSubtitles?: boolean;

    // Font family for subtitles
    fontFamily?: string;

    // Accent color for UI elements
    accentColor?: string;
  };

  // Upload metadata (not used in rendering, but stored in manifest)
  upload?: {
    caption: string;
    platforms: string[];
  };
}

// Helper to check if a file is an image
export function isImageFile(path: string): boolean {
  const ext = path.toLowerCase().split('.').pop();
  return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].includes(ext || '');
}
