import {
  AbsoluteFill,
  Audio,
  Sequence,
  Video,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
} from "remotion";

interface ClipData {
  src: string;
  durationInFrames: number;
}

interface VoiceData {
  src: string;
  startFrame: number;
}

interface ShortVideoProps {
  title: string;
  subtitle: string;
  clips: ClipData[];
  voice: VoiceData | null;
  caption: string;
}

const TitleOverlay: React.FC<{ title: string; subtitle: string }> = ({
  title,
  subtitle,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleOpacity = interpolate(frame, [0, fps * 0.5], [0, 1], {
    extrapolateRight: "clamp",
  });

  const subtitleOpacity = interpolate(
    frame,
    [fps * 0.3, fps * 0.8],
    [0, 1],
    { extrapolateRight: "clamp" }
  );

  const titleY = interpolate(frame, [0, fps * 0.5], [50, 0], {
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: "flex-end",
        alignItems: "center",
        paddingBottom: 200,
      }}
    >
      <div
        style={{
          backgroundColor: "rgba(0, 0, 0, 0.7)",
          padding: "20px 40px",
          borderRadius: 16,
          maxWidth: "90%",
        }}
      >
        <h1
          style={{
            color: "white",
            fontSize: 64,
            fontWeight: "bold",
            textAlign: "center",
            margin: 0,
            opacity: titleOpacity,
            transform: `translateY(${titleY}px)`,
            textShadow: "2px 2px 4px rgba(0,0,0,0.5)",
          }}
        >
          {title}
        </h1>
        <p
          style={{
            color: "#cccccc",
            fontSize: 36,
            textAlign: "center",
            margin: "16px 0 0 0",
            opacity: subtitleOpacity,
          }}
        >
          {subtitle}
        </p>
      </div>
    </AbsoluteFill>
  );
};

export const ShortVideo: React.FC<ShortVideoProps> = ({
  title,
  subtitle,
  clips,
  voice,
}) => {
  let currentFrame = 0;

  return (
    <AbsoluteFill style={{ backgroundColor: "#111" }}>
      {clips.map((clip, index) => {
        const startFrame = currentFrame;
        currentFrame += clip.durationInFrames;

        return (
          <Sequence
            key={index}
            from={startFrame}
            durationInFrames={clip.durationInFrames}
          >
            <Video
              src={staticFile(clip.src)}
              style={{
                width: "100%",
                height: "100%",
                objectFit: "cover",
              }}
            />
          </Sequence>
        );
      })}

      {voice && (
        <Audio src={staticFile(voice.src)} startFrom={voice.startFrame} />
      )}

      <TitleOverlay title={title} subtitle={subtitle} />
    </AbsoluteFill>
  );
};
