import React from 'react';
import { Composition } from 'remotion';
import { DevlogVideo } from './DevlogVideo';
import { DevlogVideoProps } from './types';

// Example props for preview in Remotion Studio
const exampleProps: DevlogVideoProps = {
  fps: 30,
  segments: [
    {
      voice: null,
      media: 'example/gameplay.mp4',
      duration: 3,
      subtitle: 'So I found a bug in my game...',
    },
    {
      voice: null,
      media: 'example/bug-moment.mp4',
      duration: 4,
      subtitle: 'Look at this!',
    },
    {
      voice: null,
      media: 'example/result.mp4',
      duration: 3,
      subtitle: "I think I'm keeping it.",
    },
  ],
  style: {
    subtitlePosition: 'bottom',
    showSubtitles: true,
    accentColor: '#6366f1',
  },
  upload: {
    caption: 'Found a bug, decided to keep it\n\n#gamedev #indiedev',
    platforms: ['tiktok', 'x'],
  },
};

// Calculate total duration from segments
const calculateDuration = (props: DevlogVideoProps): number => {
  return props.segments.reduce((total, segment) => {
    return total + Math.ceil((segment.duration || 3) * props.fps);
  }, 0);
};

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="DevlogVideo"
        component={DevlogVideo}
        durationInFrames={calculateDuration(exampleProps)}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={exampleProps}
        calculateMetadata={async ({ props }) => {
          return {
            durationInFrames: calculateDuration(props),
            fps: props.fps,
          };
        }}
      />
    </>
  );
};
