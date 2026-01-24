#!/usr/bin/env python3
"""
Eagle Audio Analyzer - Batch audio analysis for tagging
Extracts audio features and suggests tags for Eagle library items.

Usage:
    python3 eagle_audio_analyzer.py <audio_file>           # Analyze single file
    python3 eagle_audio_analyzer.py --batch <file_list>   # Batch mode from file list
    python3 eagle_audio_analyzer.py --json <audio_file>   # Output as JSON

Dependencies:
    - librosa (pip install librosa)
    - numpy (pip install numpy)
    - aubio CLI (brew install aubio)
    - sox CLI (brew install sox)
    - ffprobe CLI (brew install ffmpeg)
"""

import subprocess
import json
import sys
import os
from pathlib import Path

# Try to import librosa, fall back to basic analysis if not available
try:
    import librosa
    import numpy as np
    LIBROSA_AVAILABLE = True
except ImportError:
    LIBROSA_AVAILABLE = False
    print("Warning: librosa not available. Using basic analysis only.", file=sys.stderr)


def run_command(cmd, timeout=30):
    """Run shell command and return output."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return None, "timeout"
    except Exception as e:
        return None, str(e)


def analyze_with_ffprobe(filepath):
    """Extract metadata with ffprobe."""
    cmd = f'ffprobe -v quiet -print_format json -show_format -show_streams "{filepath}"'
    stdout, stderr = run_command(cmd)

    if not stdout:
        return {}

    try:
        data = json.loads(stdout)
        stream = data.get('streams', [{}])[0]
        fmt = data.get('format', {})

        return {
            'duration': float(fmt.get('duration', 0)),
            'sample_rate': int(stream.get('sample_rate', 0)),
            'channels': stream.get('channels', 0),
            'bit_depth': stream.get('bits_per_sample', 0),
            'codec': stream.get('codec_name', ''),
            'encoder': fmt.get('tags', {}).get('encoder', ''),
            'file_size': int(fmt.get('size', 0)),
        }
    except:
        return {}


def analyze_with_sox(filepath):
    """Extract audio statistics with sox."""
    cmd = f'sox "{filepath}" -n stat 2>&1'
    stdout, stderr = run_command(cmd, timeout=60)

    output = stdout or stderr
    if not output:
        return {}

    stats = {}
    for line in output.split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            key = key.strip().lower().replace(' ', '_')
            try:
                stats[key] = float(value.strip())
            except:
                stats[key] = value.strip()

    # Also get the detailed stats
    cmd2 = f'sox "{filepath}" -n stats 2>&1'
    stdout2, _ = run_command(cmd2, timeout=60)
    if stdout2:
        for line in stdout2.split('\n'):
            if 'RMS lev dB' in line:
                parts = line.split()
                if len(parts) >= 3:
                    try:
                        stats['rms_db'] = float(parts[2])
                    except:
                        pass
            if 'Pk lev dB' in line:
                parts = line.split()
                if len(parts) >= 3:
                    try:
                        stats['peak_db'] = float(parts[2])
                    except:
                        pass
            if 'Crest factor' in line:
                parts = line.split()
                if len(parts) >= 3:
                    try:
                        stats['crest_factor'] = float(parts[2])
                    except:
                        pass

    return stats


def analyze_with_aubio(filepath):
    """Extract tempo/BPM with aubio."""
    cmd = f'aubio tempo -i "{filepath}" 2>/dev/null'
    stdout, _ = run_command(cmd, timeout=60)

    if stdout and 'bpm' in stdout.lower():
        try:
            bpm = float(stdout.split()[0])
            return {'bpm': bpm}
        except:
            pass
    return {}


def analyze_with_librosa(filepath, duration_limit=60):
    """Extract detailed audio features with librosa."""
    if not LIBROSA_AVAILABLE:
        return {}

    try:
        # Load audio (limit duration for speed)
        y, sr = librosa.load(filepath, duration=duration_limit, sr=22050)

        features = {}

        # Tempo (if aubio failed)
        tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
        features['librosa_bpm'] = float(tempo)

        # Spectral features
        features['spectral_centroid'] = float(np.mean(librosa.feature.spectral_centroid(y=y, sr=sr)))
        features['spectral_rolloff'] = float(np.mean(librosa.feature.spectral_rolloff(y=y, sr=sr)))
        features['spectral_bandwidth'] = float(np.mean(librosa.feature.spectral_bandwidth(y=y, sr=sr)))
        features['zero_crossing_rate'] = float(np.mean(librosa.feature.zero_crossing_rate(y)))

        # Harmonic content (key detection)
        chroma = librosa.feature.chroma_stft(y=y, sr=sr)
        chroma_mean = np.mean(chroma, axis=1)
        key_idx = int(np.argmax(chroma_mean))
        keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        features['dominant_key'] = keys[key_idx]
        features['key_strength'] = float(np.max(chroma_mean))

        # Energy dynamics
        rms = librosa.feature.rms(y=y)[0]
        features['energy_mean'] = float(np.mean(rms))
        features['energy_std'] = float(np.std(rms))
        features['energy_variation'] = float(np.std(rms) / (np.mean(rms) + 0.0001))

        # Harmonic vs percussive
        y_harmonic, y_percussive = librosa.effects.hpss(y)
        harm_energy = np.sum(y_harmonic ** 2)
        perc_energy = np.sum(y_percussive ** 2)
        total = harm_energy + perc_energy + 0.0001
        features['harmonic_ratio'] = float(harm_energy / total)
        features['percussive_ratio'] = float(perc_energy / total)

        return features

    except Exception as e:
        return {'librosa_error': str(e)}


def infer_tags(analysis):
    """Infer tags from audio analysis."""
    tags = {
        'type': [],
        'genre': [],
        'mood': [],
        'technical': [],
        'tempo': [],
    }

    duration = analysis.get('duration', 0)
    bpm = analysis.get('bpm') or analysis.get('librosa_bpm', 0)
    rms_db = analysis.get('rms_db', -20)
    crest = analysis.get('crest_factor', 10)
    centroid = analysis.get('spectral_centroid', 1500)
    zcr = analysis.get('zero_crossing_rate', 0.05)
    harmonic = analysis.get('harmonic_ratio', 0.5)
    percussive = analysis.get('percussive_ratio', 0.5)
    channels = analysis.get('channels', 2)

    # Duration tags
    if duration < 0.5:
        tags['technical'].append('very-short')
    elif duration < 2:
        tags['technical'].append('short')
    elif duration < 30:
        tags['technical'].append('medium')
    else:
        tags['technical'].append('long')

    # Type inference based on duration and dynamics
    if duration < 5:
        tags['type'].append('sfx')
        if crest > 10:
            tags['type'].append('impact')
        if crest > 8 and duration < 1:
            tags['type'].append('one-shot')
    else:
        if analysis.get('energy_variation', 0) < 0.4:
            tags['type'].append('loop')
        tags['type'].append('music')

    # Loudness tags
    if rms_db > -12:
        tags['technical'].append('loud')
    elif rms_db < -24:
        tags['technical'].append('soft')

    # Dynamics tags
    if crest > 12:
        tags['technical'].append('punchy')
        tags['technical'].append('transient')
    elif crest < 6:
        tags['technical'].append('sustained')
        tags['technical'].append('compressed')

    # Channel tags
    if channels == 1:
        tags['technical'].append('mono')
    elif channels == 2:
        tags['technical'].append('stereo')

    # Tempo tags (for music)
    if bpm and duration > 10:
        if bpm < 80:
            tags['tempo'].append('slow')
            tags['mood'].append('peaceful')
        elif bpm < 110:
            tags['tempo'].append('medium-tempo')
        elif bpm < 140:
            tags['tempo'].append('fast')
            tags['mood'].append('energetic')
        else:
            tags['tempo'].append('very-fast')
            tags['mood'].append('intense')

        # Add BPM range tag
        bpm_rounded = int(round(bpm / 5) * 5)
        tags['tempo'].append(f'{bpm_rounded}bpm')

    # Spectral/genre inference
    if centroid > 2500:
        tags['genre'].append('bright')
        tags['genre'].append('electronic')
    elif centroid < 1200:
        tags['genre'].append('dark')
        tags['genre'].append('bass-heavy')

    if zcr > 0.15:
        tags['genre'].append('noisy')
        tags['genre'].append('percussive')
    elif zcr < 0.03:
        tags['genre'].append('smooth')
        tags['genre'].append('tonal')

    # Harmonic vs percussive
    if harmonic > 0.7:
        tags['genre'].append('melodic')
        tags['genre'].append('harmonic')
    elif percussive > 0.6:
        tags['genre'].append('rhythmic')
        tags['genre'].append('drums')

    # Key tag (if detected)
    if analysis.get('dominant_key'):
        key = analysis['dominant_key'].lower().replace('#', '-sharp')
        tags['technical'].append(f'key-{key}')

    # Flatten and dedupe
    all_tags = []
    for category_tags in tags.values():
        all_tags.extend(category_tags)

    return list(set(all_tags)), tags


def analyze_file(filepath, use_librosa=True):
    """Full analysis of a single audio file."""
    filepath = str(filepath)

    if not os.path.exists(filepath):
        return {'error': f'File not found: {filepath}'}

    analysis = {
        'filepath': filepath,
        'filename': os.path.basename(filepath),
    }

    # Run all analyzers
    analysis.update(analyze_with_ffprobe(filepath))
    analysis.update(analyze_with_sox(filepath))
    analysis.update(analyze_with_aubio(filepath))

    if use_librosa and LIBROSA_AVAILABLE:
        duration = analysis.get('duration', 0)
        # Limit librosa analysis time for long files
        limit = min(60, duration) if duration > 0 else 60
        analysis.update(analyze_with_librosa(filepath, duration_limit=limit))

    # Infer tags
    all_tags, categorized_tags = infer_tags(analysis)
    analysis['suggested_tags'] = all_tags
    analysis['tags_by_category'] = categorized_tags

    return analysis


def print_analysis(analysis, as_json=False):
    """Pretty print analysis results."""
    if as_json:
        print(json.dumps(analysis, indent=2))
        return

    print(f"\n{'='*60}")
    print(f"FILE: {analysis.get('filename', 'Unknown')}")
    print(f"{'='*60}")

    # Basic info
    duration = analysis.get('duration', 0)
    print(f"\n📊 BASIC INFO")
    print(f"   Duration: {duration:.2f}s ({duration/60:.1f} min)")
    print(f"   Sample Rate: {analysis.get('sample_rate', 'N/A')} Hz")
    print(f"   Channels: {analysis.get('channels', 'N/A')}")
    print(f"   Bit Depth: {analysis.get('bit_depth', 'N/A')}-bit")

    # Loudness
    print(f"\n🔊 LOUDNESS")
    print(f"   Peak: {analysis.get('peak_db', 'N/A')} dB")
    print(f"   RMS: {analysis.get('rms_db', 'N/A')} dB")
    print(f"   Crest Factor: {analysis.get('crest_factor', 'N/A')}")

    # Tempo/Rhythm
    bpm = analysis.get('bpm') or analysis.get('librosa_bpm')
    if bpm:
        print(f"\n🥁 RHYTHM")
        print(f"   BPM: {bpm:.1f}")

    # Spectral
    if analysis.get('spectral_centroid'):
        print(f"\n🌈 SPECTRAL")
        print(f"   Centroid: {analysis.get('spectral_centroid', 0):.0f} Hz")
        print(f"   Rolloff: {analysis.get('spectral_rolloff', 0):.0f} Hz")
        print(f"   Zero Crossing: {analysis.get('zero_crossing_rate', 0):.4f}")

    # Harmonic content
    if analysis.get('dominant_key'):
        print(f"\n🎵 HARMONIC")
        print(f"   Key: {analysis.get('dominant_key')}")
        print(f"   Harmonic Ratio: {analysis.get('harmonic_ratio', 0):.1%}")
        print(f"   Percussive Ratio: {analysis.get('percussive_ratio', 0):.1%}")

    # Tags
    print(f"\n🏷️  SUGGESTED TAGS")
    tags_by_cat = analysis.get('tags_by_category', {})
    for category, tags in tags_by_cat.items():
        if tags:
            print(f"   {category.upper()}: {', '.join(tags)}")

    print(f"\n   ALL: {', '.join(analysis.get('suggested_tags', []))}")
    print()


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Analyze audio files for Eagle tagging')
    parser.add_argument('filepath', nargs='?', help='Audio file to analyze')
    parser.add_argument('--batch', type=str, help='File containing list of audio paths')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    parser.add_argument('--no-librosa', action='store_true', help='Skip librosa analysis')

    args = parser.parse_args()

    if args.batch:
        # Batch mode
        with open(args.batch) as f:
            files = [line.strip() for line in f if line.strip()]

        results = []
        for i, filepath in enumerate(files):
            print(f"Analyzing {i+1}/{len(files)}: {os.path.basename(filepath)}", file=sys.stderr)
            result = analyze_file(filepath, use_librosa=not args.no_librosa)
            results.append(result)

        if args.json:
            print(json.dumps(results, indent=2))
        else:
            for result in results:
                print_analysis(result)

    elif args.filepath:
        # Single file mode
        result = analyze_file(args.filepath, use_librosa=not args.no_librosa)
        print_analysis(result, as_json=args.json)
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
