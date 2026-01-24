import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Img,
  Sequence,
  Video,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
  Easing,
} from 'remotion';
import {
  DevlogVideoProps,
  Segment,
  isImageFile,
  TransitionType,
  KenBurnsType,
  TextAnimationType,
} from './types';

// ============================================
// TEXT ANIMATIONS
// ============================================

// Word-by-word animated text (TikTok style) - "pop"
const AnimatedWordPop: React.FC<{
  word: string;
  delay: number;
  accentColor: string;
}> = ({ word, delay, accentColor }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const scale = spring({
    frame: frame - delay,
    fps,
    config: { damping: 12, stiffness: 200, mass: 0.5 },
  });

  const opacity = interpolate(frame - delay, [0, 3], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const translateY = interpolate(frame - delay, [0, 6], [20, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.back(1.5)),
  });

  if (frame < delay) return null;

  return (
    <span style={{
      display: 'inline-block',
      opacity,
      transform: `scale(${scale}) translateY(${translateY}px)`,
      marginRight: '0.25em',
    }}>
      {word}
    </span>
  );
};

// Slide up animation
const AnimatedWordSlideUp: React.FC<{
  word: string;
  delay: number;
}> = ({ word, delay }) => {
  const frame = useCurrentFrame();

  const opacity = interpolate(frame - delay, [0, 6], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const translateY = interpolate(frame - delay, [0, 8], [40, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  if (frame < delay) return null;

  return (
    <span style={{
      display: 'inline-block',
      opacity,
      transform: `translateY(${translateY}px)`,
      marginRight: '0.25em',
    }}>
      {word}
    </span>
  );
};

// Wave animation
const AnimatedWordWave: React.FC<{
  word: string;
  delay: number;
  index: number;
}> = ({ word, delay, index }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const waveOffset = Math.sin((frame - delay) * 0.3 + index * 0.5) * 8;

  const opacity = interpolate(frame - delay, [0, 4], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  if (frame < delay) return null;

  return (
    <span style={{
      display: 'inline-block',
      opacity,
      transform: `translateY(${waveOffset}px)`,
      marginRight: '0.25em',
    }}>
      {word}
    </span>
  );
};

// Typewriter (character by character)
const TypewriterText: React.FC<{
  text: string;
  durationInFrames: number;
}> = ({ text, durationInFrames }) => {
  const frame = useCurrentFrame();

  const charsToShow = Math.floor(
    interpolate(frame, [0, durationInFrames * 0.7], [0, text.length], {
      extrapolateRight: 'clamp',
    })
  );

  return <span>{text.slice(0, charsToShow)}</span>;
};

// Subtitle component with multiple animation types
const AnimatedSubtitle: React.FC<{
  text: string;
  durationInFrames: number;
  position: 'top' | 'center' | 'bottom';
  accentColor: string;
  fontFamily: string;
  animationType: TextAnimationType;
}> = ({ text, durationInFrames, position, accentColor, fontFamily, animationType }) => {
  const frame = useCurrentFrame();
  const words = text.split(' ');
  const totalWords = words.length;
  const revealDuration = durationInFrames * 0.7;
  const framesPerWord = Math.max(4, Math.floor(revealDuration / totalWords));

  const positionStyles: Record<string, React.CSSProperties> = {
    top: { top: 120, bottom: 'auto' },
    center: { top: '45%' },
    bottom: { bottom: 180, top: 'auto' },
  };

  // Simple fade for entire text
  const fadeOpacity = animationType === 'fade'
    ? interpolate(frame, [0, 15], [0, 1], { extrapolateRight: 'clamp' })
    : 1;

  const textStyle: React.CSSProperties = {
    fontSize: 58,
    fontWeight: 800,
    margin: 0,
    fontFamily,
    lineHeight: 1.2,
    letterSpacing: '-0.02em',
    color: '#ffffff',
    textShadow: `
      3px 3px 0 ${accentColor},
      -3px -3px 0 ${accentColor},
      3px -3px 0 ${accentColor},
      -3px 3px 0 ${accentColor},
      3px 0 0 ${accentColor},
      -3px 0 0 ${accentColor},
      0 3px 0 ${accentColor},
      0 -3px 0 ${accentColor},
      0 6px 20px rgba(0,0,0,0.5)
    `,
  };

  const renderContent = () => {
    switch (animationType) {
      case 'typewriter':
        return <TypewriterText text={text} durationInFrames={durationInFrames} />;

      case 'slide-up':
        return words.map((word, index) => (
          <AnimatedWordSlideUp
            key={index}
            word={word}
            delay={index * framesPerWord}
          />
        ));

      case 'wave':
        return words.map((word, index) => (
          <AnimatedWordWave
            key={index}
            word={word}
            delay={index * framesPerWord}
            index={index}
          />
        ));

      case 'fade':
      case 'none':
        return <span style={{ opacity: fadeOpacity }}>{text}</span>;

      case 'pop':
      default:
        return words.map((word, index) => (
          <AnimatedWordPop
            key={index}
            word={word}
            delay={index * framesPerWord}
            accentColor={accentColor}
          />
        ));
    }
  };

  return (
    <AbsoluteFill style={{ justifyContent: 'center', alignItems: 'center', pointerEvents: 'none' }}>
      <div style={{ position: 'absolute', left: 50, right: 50, textAlign: 'center', ...positionStyles[position] }}>
        <p style={textStyle}>{renderContent()}</p>
      </div>
    </AbsoluteFill>
  );
};

// ============================================
// MEDIA SEGMENT WITH TRANSITIONS
// ============================================

const MediaSegment: React.FC<{
  segment: Segment;
  durationInFrames: number;
  isFirst: boolean;
  isLast: boolean;
}> = ({ segment, durationInFrames, isFirst, isLast }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  const isImage = segment.isImage ?? isImageFile(segment.media);

  const transition = segment.transition || 'fade';
  const kenBurns = segment.kenBurns || 'zoom-in';

  const transitionDuration = 10; // frames

  // ============================================
  // TRANSITION ANIMATIONS (entry/exit)
  // ============================================

  let transitionTransform = '';
  let transitionOpacity = 1;
  let clipPath = 'none';

  // Entry animation (first N frames)
  const entryProgress = interpolate(frame, [0, transitionDuration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  // Exit animation (last N frames)
  const exitProgress = interpolate(
    frame,
    [durationInFrames - transitionDuration, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.in(Easing.cubic) }
  );

  const progress = isFirst ? 1 : entryProgress;
  const exitOpacity = isLast ? 1 : exitProgress;

  switch (transition) {
    case 'cut':
      transitionOpacity = 1;
      break;

    case 'slide-left':
      transitionTransform = `translateX(${(1 - progress) * 100}%)`;
      break;

    case 'slide-right':
      transitionTransform = `translateX(${(1 - progress) * -100}%)`;
      break;

    case 'slide-up':
      transitionTransform = `translateY(${(1 - progress) * 100}%)`;
      break;

    case 'slide-down':
      transitionTransform = `translateY(${(1 - progress) * -100}%)`;
      break;

    case 'zoom-in':
      const zoomScale = interpolate(progress, [0, 1], [0.5, 1]);
      transitionTransform = `scale(${zoomScale})`;
      transitionOpacity = progress;
      break;

    case 'zoom-out':
      const shrinkScale = interpolate(progress, [0, 1], [1.5, 1]);
      transitionTransform = `scale(${shrinkScale})`;
      transitionOpacity = progress;
      break;

    case 'wipe-left':
      clipPath = `inset(0 ${(1 - progress) * 100}% 0 0)`;
      break;

    case 'blur':
      // Blur handled separately
      transitionOpacity = progress;
      break;

    case 'fade':
    default:
      transitionOpacity = progress;
      break;
  }

  // Combine with exit opacity
  transitionOpacity = Math.min(transitionOpacity, exitOpacity);

  // ============================================
  // KEN BURNS (camera motion during segment)
  // ============================================

  let kenBurnsTransform = '';

  const kbProgress = interpolate(frame, [0, durationInFrames], [0, 1], {
    extrapolateRight: 'clamp',
  });

  switch (kenBurns) {
    case 'zoom-in':
      const zoomIn = interpolate(kbProgress, [0, 1], [1.0, 1.1]);
      kenBurnsTransform = `scale(${zoomIn})`;
      break;

    case 'zoom-out':
      const zoomOut = interpolate(kbProgress, [0, 1], [1.1, 1.0]);
      kenBurnsTransform = `scale(${zoomOut})`;
      break;

    case 'pan-left':
      const panLeft = interpolate(kbProgress, [0, 1], [5, -5]);
      kenBurnsTransform = `scale(1.1) translateX(${panLeft}%)`;
      break;

    case 'pan-right':
      const panRight = interpolate(kbProgress, [0, 1], [-5, 5]);
      kenBurnsTransform = `scale(1.1) translateX(${panRight}%)`;
      break;

    case 'pan-up':
      const panUp = interpolate(kbProgress, [0, 1], [5, -5]);
      kenBurnsTransform = `scale(1.1) translateY(${panUp}%)`;
      break;

    case 'pan-down':
      const panDown = interpolate(kbProgress, [0, 1], [-5, 5]);
      kenBurnsTransform = `scale(1.1) translateY(${panDown}%)`;
      break;

    case 'none':
    default:
      kenBurnsTransform = '';
      break;
  }

  // Combine transforms
  const combinedTransform = [transitionTransform, kenBurnsTransform]
    .filter(Boolean)
    .join(' ');

  // ============================================
  // STYLES
  // ============================================

  const cropStyle: React.CSSProperties = segment.crop
    ? {
        objectFit: 'none' as const,
        objectPosition: `-${segment.crop.x}px -${segment.crop.y}px`,
        width: segment.crop.width || width,
        height: segment.crop.height || height,
      }
    : {
        objectFit: 'cover' as const,
        width: '100%',
        height: '100%',
      };

  const containerStyle: React.CSSProperties = {
    transform: combinedTransform || undefined,
    opacity: transitionOpacity,
    width: '100%',
    height: '100%',
    clipPath: clipPath !== 'none' ? clipPath : undefined,
    filter: transition === 'blur' ? `blur(${(1 - entryProgress) * 20}px)` : undefined,
  };

  if (isImage) {
    return (
      <div style={containerStyle}>
        <Img src={staticFile(segment.media)} style={cropStyle} />
      </div>
    );
  }

  return (
    <div style={containerStyle}>
      <Video
        src={staticFile(segment.media)}
        startFrom={Math.floor((segment.mediaStartTime || 0) * fps)}
        style={cropStyle}
      />
    </div>
  );
};

// ============================================
// VIGNETTE OVERLAY
// ============================================

const VignetteOverlay: React.FC = () => {
  return (
    <AbsoluteFill
      style={{
        background: 'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.4) 100%)',
        pointerEvents: 'none',
      }}
    />
  );
};

// ============================================
// MAIN COMPOSITION
// ============================================

export const DevlogVideo: React.FC<DevlogVideoProps> = ({
  fps,
  segments,
  style = {},
}) => {
  const {
    subtitlePosition = 'bottom',
    showSubtitles = true,
    fontFamily = '"Inter", "SF Pro Display", -apple-system, BlinkMacSystemFont, sans-serif',
    accentColor = '#ff6b6b',
  } = style;

  // Calculate frame positions for each segment
  const segmentData = segments.map((segment) => {
    const durationInSeconds = segment.duration || 3;
    const durationInFrames = Math.ceil(durationInSeconds * fps);
    return { segment, durationInFrames };
  });

  // Calculate start frames
  let currentFrame = 0;
  const segmentsWithTiming = segmentData.map((data, index) => {
    const startFrame = currentFrame;
    currentFrame += data.durationInFrames;
    return {
      ...data,
      startFrame,
      isFirst: index === 0,
      isLast: index === segmentData.length - 1,
    };
  });

  return (
    <AbsoluteFill style={{ backgroundColor: '#0a0a0a' }}>
      {/* Media layers with transitions */}
      {segmentsWithTiming.map((data, index) => (
        <Sequence
          key={`media-${index}`}
          from={data.startFrame}
          durationInFrames={data.durationInFrames}
        >
          <MediaSegment
            segment={data.segment}
            durationInFrames={data.durationInFrames}
            isFirst={data.isFirst}
            isLast={data.isLast}
          />
        </Sequence>
      ))}

      {/* Vignette for cinematic feel */}
      <VignetteOverlay />

      {/* Voice audio layers */}
      {segmentsWithTiming.map((data, index) =>
        data.segment.voice ? (
          <Sequence
            key={`audio-${index}`}
            from={data.startFrame}
            durationInFrames={data.durationInFrames}
          >
            <Audio src={staticFile(data.segment.voice)} />
          </Sequence>
        ) : null
      )}

      {/* SFX audio layers */}
      {segmentsWithTiming.map((data, index) =>
        data.segment.sfx ? (
          <Sequence
            key={`sfx-${index}`}
            from={data.startFrame + Math.floor((data.segment.sfxOffset || 0) * fps)}
            durationInFrames={data.durationInFrames}
          >
            <Audio
              src={staticFile(data.segment.sfx)}
              volume={data.segment.sfxVolume ?? 0.5}
            />
          </Sequence>
        ) : null
      )}

      {/* Animated subtitles */}
      {showSubtitles &&
        segmentsWithTiming.map((data, index) =>
          data.segment.subtitle ? (
            <Sequence
              key={`subtitle-${index}`}
              from={data.startFrame}
              durationInFrames={data.durationInFrames}
            >
              <AnimatedSubtitle
                text={data.segment.subtitle}
                durationInFrames={data.durationInFrames}
                position={subtitlePosition}
                accentColor={accentColor}
                fontFamily={fontFamily}
                animationType={data.segment.textAnimation || 'pop'}
              />
            </Sequence>
          ) : null
        )}
    </AbsoluteFill>
  );
};
