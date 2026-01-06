#!/bin/bash
# benchmarks/scripts/setup_data.sh
# Download and prepare test data for benchmarks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$(dirname "$SCRIPT_DIR")/data"

echo "Setting up benchmark test data..."
echo "Data directory: $DATA_DIR"

# Create data directories
mkdir -p "$DATA_DIR"/{imagenet_sample,video_samples,dna_sequences,text_corpus}

# ============================================================================
# ImageNet Sample Data (for ResNet benchmark)
# ============================================================================
echo ""
echo "Setting up ImageNet sample data..."
cd "$DATA_DIR/imagenet_sample"

if [ ! -f "sample_images.tar.gz" ]; then
    echo "  Generating sample images..."
    # Create 1000 random images (224x224) instead of downloading
    mkdir -p images
    for i in $(seq 1 1000); do
        # Create random noise image using ImageMagick or Python
        if command -v convert &> /dev/null; then
            convert -size 224x224 plasma:fractal "images/img_$(printf %04d $i).jpg"
        else
            # Use Python if ImageMagick not available
            python3 -c "
from PIL import Image
import numpy as np
img = Image.fromarray(np.random.randint(0, 256, (224, 224, 3), dtype=np.uint8))
img.save('images/img_$(printf %04d $i).jpg')
" 2>/dev/null || echo "    Skipping image $i (no PIL/ImageMagick)"
        fi
        
        if [ $((i % 100)) -eq 0 ]; then
            echo "    Generated $i/1000 images"
        fi
    done
    
    tar -czf sample_images.tar.gz images/
    rm -rf images/
    echo "  ✓ ImageNet sample created (1000 images)"
else
    echo "  ✓ ImageNet sample already exists"
fi

# ============================================================================
# Video Samples (for video encoding benchmark)
# ============================================================================
echo ""
echo "Setting up video sample data..."
cd "$DATA_DIR/video_samples"

if [ ! -f "sample_video.mp4" ]; then
    echo "  Generating sample video..."
    
    if command -v ffmpeg &> /dev/null; then
        # Generate 10-second test video with testsrc
        ffmpeg -f lavfi -i testsrc=duration=10:size=1920x1080:rate=30 \
               -c:v libx264 -pix_fmt yuv420p sample_video.mp4 -y &> /dev/null
        echo "  ✓ Video sample created (10s, 1920x1080, 30fps)"
    else
        echo "  ⚠ ffmpeg not found, creating placeholder"
        echo "Video sample requires ffmpeg to generate" > README.txt
    fi
else
    echo "  ✓ Video sample already exists"
fi

# ============================================================================
# DNA Sequences (for bioinformatics benchmark)
# ============================================================================
echo ""
echo "Setting up DNA sequence data..."
cd "$DATA_DIR/dna_sequences"

if [ ! -f "sequences.fasta" ]; then
    echo "  Generating DNA sequences..."
    
    # Generate random DNA sequences
    cat > sequences.fasta << 'EOF'
>seq001 Random DNA sequence 1
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA
>seq002 Random DNA sequence 2
CGTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA
GCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
>seq003 Random DNA sequence 3
GGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCC
GGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCCGGCC
TTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAA
TTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAATTAA
EOF
    
    # Generate more sequences programmatically
    for i in $(seq 4 1000); do
        echo ">seq$(printf %03d $i) Random DNA sequence $i"
        # Generate 240 random bases (4 lines of 60 each)
        for line in {1..4}; do
            cat /dev/urandom | tr -dc 'ATCG' | fold -w 60 | head -n 1
        done
    done >> sequences.fasta
    
    echo "  ✓ DNA sequences created (1000 sequences)"
else
    echo "  ✓ DNA sequences already exist"
fi

# ============================================================================
# Text Corpus (for MapReduce benchmark)
# ============================================================================
echo ""
echo "Setting up text corpus data..."
cd "$DATA_DIR/text_corpus"

if [ ! -f "corpus.txt" ]; then
    echo "  Generating text corpus..."
    
    # Generate sample text corpus
    cat > corpus.txt << 'EOF'
The quick brown fox jumps over the lazy dog. This is a sample text corpus
for testing MapReduce word count benchmarks. MapReduce is a programming model
for processing large data sets with a parallel distributed algorithm on a cluster.

The MapReduce framework consists of two main phases: the map phase and the
reduce phase. In the map phase, the input data is divided into smaller chunks
which are then processed in parallel. The reduce phase then aggregates the
results from the map phase.

Energy-aware task scheduling is crucial for modern computing systems. By
optimizing the allocation of computational resources, we can significantly
reduce energy consumption while maintaining performance. This is particularly
important in data centers where energy costs represent a substantial portion
of operational expenses.

The AutoScheduler system provides intelligent task scheduling with energy
optimization. It analyzes workload characteristics and system resources to
make optimal scheduling decisions. The system supports heterogeneous computing
environments including CPUs, GPUs, and other accelerators.

EOF
    
    # Replicate the text to create a larger corpus
    for i in {1..100}; do
        cat corpus.txt >> corpus_full.txt
    done
    mv corpus_full.txt corpus.txt
    
    echo "  ✓ Text corpus created (~50KB)"
else
    echo "  ✓ Text corpus already exists"
fi

# ============================================================================
# Create README files
# ============================================================================
echo ""
echo "Creating README files..."

cat > "$DATA_DIR/README.md" << 'EOF'
# Benchmark Test Data

This directory contains test data for AutoScheduler benchmarks.

## Data Sets

### imagenet_sample/
Sample images for ResNet-50 training benchmark.
- 1000 synthetic images (224x224 RGB)
- Format: JPEG
- Total size: ~10MB

### video_samples/
Video files for encoding benchmark.
- Sample video: 10 seconds, 1920x1080, 30fps
- Format: MP4 (H.264)
- Total size: ~5MB

### dna_sequences/
DNA sequences for bioinformatics benchmark.
- 1000 random DNA sequences
- Format: FASTA
- Total size: ~250KB

### text_corpus/
Text data for MapReduce word count benchmark.
- Sample text corpus
- Format: Plain text
- Total size: ~50KB

## Regenerating Data

To regenerate all test data:
```bash
cd benchmarks/scripts
./setup_data.sh
```

## Custom Data

You can replace any of these datasets with your own data. Just ensure
the format matches what the benchmarks expect.
EOF

echo ""
echo "============================================"
echo "✓ Benchmark test data setup complete!"
echo "============================================"
echo ""
echo "Data summary:"
echo "  ImageNet sample:  $(du -sh "$DATA_DIR/imagenet_sample" | cut -f1)"
echo "  Video samples:    $(du -sh "$DATA_DIR/video_samples" | cut -f1)"
echo "  DNA sequences:    $(du -sh "$DATA_DIR/dna_sequences" | cut -f1)"
echo "  Text corpus:      $(du -sh "$DATA_DIR/text_corpus" | cut -f1)"
echo ""
echo "Total data size:    $(du -sh "$DATA_DIR" | cut -f1)"
echo ""
echo "You can now run benchmarks with:"
echo "  julia benchmarks/run_all.jl"
echo ""